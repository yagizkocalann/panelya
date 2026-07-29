import 'dart:async';
import 'dart:math';

import '../../../app/router/deep_link.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../../core/storage/token_store.dart';
import '../domain/auth_exceptions.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session_state.dart';
import 'pkce.dart';

/// [AuthRepository]'nin `/api/auth/*` uçlarına konuşan gerçek
/// implementasyonu (bkz. ADR-039, docs/production-auth-session.md).
///
/// `authRepositoryProvider` (bkz. `features/auth/presentation/
/// auth_providers.dart`) bunu bağlar. Gerçek Auth0 dev tenant'ı (PR #36,
/// `main@b8e39da`) canlıda doğrulandı; web tarafı `/api/auth/config`'i
/// yalnız tenant/gateway değerleri eksikken "fail closed" döndürür (bkz.
/// `app/lib/production-auth.ts` -> `productionAuthUnavailable()`, HTTP 503,
/// `error: "service_unavailable"`) — bu sınıf o durumu da doğru şekilde
/// [AuthProviderErrorException] olarak yüzeye çıkarır.
///
/// Kurucu, yapıldığı anda best-effort bir arka plan görevi başlatır
/// ([_restoreSession]): [TokenStore]'da saklı bir oturum varsa
/// `/api/auth/me` ile doğrular (gerekirse `refresh()` dener) ve
/// [currentState]'i sessizce [AuthAuthenticated]'e taşır — bu, uygulama
/// yeniden açıldığında oturumun devam etmesini sağlar. Bu görev asla
/// exception fırlatmaz (çağıran/UI tarafından beklenmez); ağ/servis
/// hataları oturumu KAYBETMEDEN sessizce yutulur, bir sonraki açılışta
/// tekrar denenir.
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({
    required this._client,
    TokenStore? tokenStore,
    Random? random,
  }) : _tokenStore = tokenStore ?? InMemoryTokenStore(),
       _random = random ?? Random.secure() {
    unawaited(_restoreSession());
  }

  final PanelyaApiClient _client;
  final TokenStore _tokenStore;
  final Random _random;
  final _stateController = StreamController<AuthSessionState>.broadcast();

  AuthSessionState _state = const AuthSessionState.anonymous();
  PkcePair? _pendingPkce;
  String? _pendingState;

  @override
  AuthSessionState get currentState => _state;

  @override
  Stream<AuthSessionState> get stateChanges async* {
    yield _state;
    yield* _stateController.stream;
  }

  void _emit(AuthSessionState next) {
    _state = next;
    _stateController.add(next);
  }

  String _opaqueState() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  Future<AuthorizationRequest> beginSignIn() async {
    // `GET /api/auth/config` gerçek tenant sağlanmadan `503
    // service_unavailable` döner (bkz. sınıf dokümantasyonu); bu çağrı
    // [AuthProviderErrorException] olarak doğru şekilde yüzeye çıkar —
    // sessizce yanlış bir URL üretmez.
    AuthProviderConfigResponse config;
    try {
      config = await _client.fetchAuthConfig();
    } on AuthApiException catch (cause) {
      throw AuthProviderErrorException(cause.error);
    }

    final pkce = PkcePair.generate(random: _random);
    final state = _opaqueState();
    _pendingPkce = pkce;
    _pendingState = state;

    final url = Uri.parse(config.authorizationEndpoint).replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': config.clientId,
        'redirect_uri': authCallbackRedirectUri,
        'audience': config.audience,
        'scope': config.scopes.join(' '),
        'state': state,
        'code_challenge': pkce.challenge,
        'code_challenge_method': 'S256',
        // Auth0 giriş ekranını Türkçe göster (bkz. görev talimatı). Auth0
        // desteklenmeyen/eksik çeviri için kendi varsayılan diline düşer;
        // bu istemci tarafında ayrıca bir yedek mantık gerektirmez.
        'ui_locales': 'tr',
      },
    );

    return AuthorizationRequest(
      authorizationUrl: url,
      callbackUrlScheme: 'panelya',
    );
  }

  @override
  Future<void> completeSignIn(Uri callbackUri) async {
    if (!isAuthCallbackUri(callbackUri)) {
      throw const AuthCallbackException(
        'Beklenmeyen callback URI: panelya://auth/callback biçiminde değil.',
      );
    }

    final pendingPkce = _pendingPkce;
    final pendingState = _pendingState;
    if (pendingPkce == null || pendingState == null) {
      throw const AuthCallbackException(
        'beginSignIn() çağrılmadan callback alındı.',
      );
    }
    _pendingPkce = null;
    _pendingState = null;

    final params = callbackUri.queryParameters;
    final providerError = params['error'];
    if (providerError == 'access_denied') {
      throw const AuthUserCancelledException();
    }
    if (providerError != null) {
      throw AuthProviderErrorException(
        AuthErrorResponse(
          schemaVersion: kSchemaVersion,
          error: providerError,
          errorDescription: params['error_description'],
          reauthenticate: true,
        ),
      );
    }

    if (params['state'] != pendingState) {
      throw const AuthCallbackException(
        'state uyuşmuyor (CSRF koruması tetiklendi).',
      );
    }

    final code = params['code'];
    if (code == null || code.isEmpty) {
      throw const AuthCallbackException('callback code parametresi eksik.');
    }

    try {
      final tokens = await _client.exchangeAuthorizationCode(
        AuthAuthorizationCodeExchangeRequest(
          grantType: 'authorization_code',
          authorizationCode: code,
          codeVerifier: pendingPkce.verifier,
          redirectUri: authCallbackRedirectUri,
        ),
      );
      // Sözleşme gereği ikinci bir doğrulama katmanı (bkz. görev talimatı
      // "code/verifier değişimi ve /api/auth/me doğrulaması"): yeni access
      // token'ın gerçekten API'nin kendi kullanıcı uç noktasında da
      // `authenticated: true` döndürdüğünü teyit etmeden oturumu
      // [AuthAuthenticated]'e taşımayız. Token değişimi zaten sunucu
      // tarafında JWKS ile doğrulanmıştır (bkz. `app/lib/auth0-runtime.ts`
      // -> `validateAuth0AccessToken`); bu adım o doğrulamanın istemci
      // tarafından da gözlemlenebilir olmasını sağlar.
      final state = await _client.fetchAuthState(accessToken: tokens.accessToken);
      if (!state.authenticated || state.user == null) {
        throw AuthProviderErrorException(
          AuthErrorResponse(
            schemaVersion: kSchemaVersion,
            error: 'service_unavailable',
            errorDescription: '/api/auth/me yeni tokeni doğrulamadı.',
            reauthenticate: false,
          ),
        );
      }
      await _tokenStore.write(tokens);
      _emit(AuthSessionState.authenticated(tokens.user));
    } on AuthApiException catch (cause) {
      throw AuthProviderErrorException(cause.error);
    }
  }

  /// Uygulama açılışında saklı oturumu geri yükler (bkz. sınıf
  /// dokümantasyonu). Yalnız kurucudan, tek seferlik çağrılır.
  Future<void> _restoreSession() async {
    final stored = await _tokenStore.read();
    if (stored == null) return;

    try {
      final state = await _client.fetchAuthState(
        accessToken: stored.accessToken,
      );
      if (state.authenticated && state.user != null) {
        _emit(AuthSessionState.authenticated(state.user!));
        return;
      }
      // `authenticated: false` ama exception yok: bearer yolunda pratikte
      // beklenmez (geçersiz/süresi dolmuş token her zaman hata fırlatır,
      // bkz. `app/api/auth/me/route.ts`), ama savunma amaçlı ele alınır —
      // sahte bir oturum GÖSTERİLMEZ.
      await _tokenStore.clear();
    } on AuthApiException catch (cause) {
      if (!cause.error.reauthenticate) {
        // `rate_limited`/`service_unavailable` gibi GEÇİCİ hatalar: token'lar
        // silinmez, oturum bir sonraki açılışta veya ilk API çağrısında
        // tekrar denenir. Durum anonim kalır (ADR-010 fail-closed) — sahte
        // bir "başarılı giriş" gösterilmez.
        return;
      }
      // `token_expired`/`login_required`/`session_revoked`/`token_reused`:
      // önce yenilemeyi dene; `refresh()` reauthenticate hatalarında
      // kendi içinde temizlik yapar (bkz. o metot).
      try {
        await refresh();
      } on AuthRepositoryException {
        // Yenileme de başarısız oldu; `refresh()` zaten uygun durumu
        // (temizlenmiş veya olduğu gibi bırakılmış) ayarladı.
      }
    } catch (_) {
      // Ağ hatası vb.: token'lar dokunulmadan kalır, sonraki açılışta
      // tekrar denenir.
    }
  }

  @override
  Future<void> refresh() async {
    final stored = await _tokenStore.read();
    if (stored == null) {
      throw const AuthNotAuthenticatedException();
    }
    try {
      final rotated = await _client.refreshAuthToken(
        AuthRefreshTokenRequest(
          grantType: 'refresh_token',
          refreshToken: stored.refreshToken,
        ),
      );
      // Rotasyon: yeni token seti tek bir `write()` ile eskisinin yerine
      // ATOMIK olarak geçer (bkz. ADR-039 — istemci eskisini yeni değeri
      // yazmadan SİLMEZ).
      await _tokenStore.write(rotated);
      _emit(AuthSessionState.authenticated(rotated.user));
    } on AuthApiException catch (cause) {
      // `token_reused`/`session_revoked`: sağlayıcı tüm token ailesini
      // iptal etti; istemci de kendi kopyasını temizleyip yeniden girişe
      // yönlendirmelidir (bkz. ADR-039 "Oturum ve hata kuralları").
      if (cause.error.reauthenticate) {
        await _tokenStore.clear();
        _emit(const AuthSessionState.anonymous());
      }
      throw AuthProviderErrorException(cause.error);
    }
  }

  @override
  Future<void> logout() async {
    final stored = await _tokenStore.read();
    if (stored != null) {
      try {
        await _client.revokeAuthToken(
          AuthRevokeRequest(refreshToken: stored.refreshToken),
        );
      } on AuthApiException {
        // ADR-039: "Logout/revoke ... aynı isteğin tekrarını başarılı
        // kabul eder" — istemci tarafında da revoke çağrısı başarısız
        // olsa bile yerel oturum temizlenir; kullanıcı en kötü ihtimalle
        // sunucu tarafında en geç 15 dakika içinde access token'ın doğal
        // sona ermesiyle güvenlik altındadır.
      }
    }
    await _tokenStore.clear();
    _emit(const AuthSessionState.anonymous());
  }

  @override
  void dispose() {
    _stateController.close();
  }
}
