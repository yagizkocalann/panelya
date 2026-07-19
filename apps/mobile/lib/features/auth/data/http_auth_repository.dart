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

/// [AuthRepository]'nin `/api/auth/*` uçlarına konuşan İSKELETİ (bkz. görev
/// talimatı madde 2b).
///
/// BU SINIF BUGÜN HİÇBİR RIVERPOD PROVIDER'INDAN BAĞLANMAZ VE ÇAĞRILMAZ.
/// `authRepositoryProvider` (bkz. `features/auth/presentation/
/// auth_providers.dart`) yalnız `FakeAuthRepository`'yi bağlar. Web
/// tarafı bu uçları bugün kasıtlı olarak "fail closed" döndürür (bkz.
/// `app/lib/production-auth.ts` -> `productionAuthUnavailable()`, HTTP 503,
/// `error: "service_unavailable"`) çünkü gerçek Auth0 tenant/gateway/JWKS
/// entegrasyonu ayrı bir runtime teslimidir (bkz. ADR-039 "Kalan deployment
/// kapıları", docs/mobile-handoff.md "Şimdilik sonraya bırakılanlar").
///
/// Gerçek tenant/gateway hazır olduğunda geçiş TEK NOKTADAN yapılır:
/// `authRepositoryProvider` içindeki `FakeAuthRepository(...)`
/// örneklemesi bu sınıfla değiştirilir; bu dosyanın kendisi (mantığı zaten
/// sözleşmeye göre yazılmıştır) değişmeden kalması beklenir — yalnız
/// [AuthBrowser] gerçek bir implementasyonla (bkz. `auth_browser.dart`)
/// değiştirilmesi gerekir.
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({
    required this._client,
    TokenStore? tokenStore,
    Random? random,
  }) : _tokenStore = tokenStore ?? InMemoryTokenStore(),
       _random = random ?? Random.secure();

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
      await _tokenStore.write(tokens);
      _emit(AuthSessionState.authenticated(tokens.user));
    } on AuthApiException catch (cause) {
      throw AuthProviderErrorException(cause.error);
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
