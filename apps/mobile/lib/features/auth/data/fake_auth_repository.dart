import 'dart:async';
import 'dart:math';

import '../../../app/router/deep_link.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../../core/storage/token_store.dart';
import '../domain/auth_exceptions.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session_state.dart';
import 'pkce.dart';

/// [AuthRepository]'nin in-memory sahte implementasyonu — testler ve
/// geliştirme için (bkz. görev talimatı madde 2a). Riverpod provider'ları
/// bugün BUNU bağlar (`authRepositoryProvider`); gerçek Auth0 tenant/
/// gateway/JWKS değerleri sağlandığında `HttpAuthRepository`'ye geçiş tek
/// satırda yapılır.
///
/// Ürettiği token/kullanıcı DEĞERLERİ hiçbir zaman
/// `packages/contracts/fixtures/auth-*.v1.json` içindeki sentetik
/// STRING'lerin birebir kopyası DEĞİLDİR (bkz. görev talimatı "fixture
/// ŞEKİLLERİNİ, değerlerini runtime'a gömmeden, kullanan"); yalnız o
/// fixture'ların doğruladığı ŞEKLİ (aynı üretilen `AuthTokenResponse`/
/// `AuthUser` DTO'ları) paylaşır. Kendi rastgele/açıkça-sahte
/// değerlerini her çağrıda yeniden üretir.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({TokenStore? tokenStore, Random? random})
    : _tokenStore = tokenStore ?? InMemoryTokenStore(),
      _random = random ?? Random.secure();

  final TokenStore _tokenStore;
  final Random _random;
  final _stateController = StreamController<AuthSessionState>.broadcast();

  AuthSessionState _state = const AuthSessionState.anonymous();
  PkcePair? _pendingPkce;
  String? _pendingState;

  static const _fakeUser = AuthUser(
    id: 'local-fake-user',
    displayName: 'Yerel Test Kullanıcısı',
    email: 'fake-user@panelya.invalid',
    emailVerified: true,
    role: 'reader',
  );

  static const _fakeScopes = [
    'openid',
    'profile',
    'email',
    'offline_access',
    'read:library',
    'write:library',
    'write:progress',
    'write:community',
  ];

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

  String _opaqueToken() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  Future<AuthorizationRequest> beginSignIn() async {
    final pkce = PkcePair.generate(random: _random);
    final state = _opaqueToken();
    _pendingPkce = pkce;
    _pendingState = state;

    final url = Uri.https('fake-auth.panelya.invalid', '/authorize', {
      'response_type': 'code',
      'client_id': 'fake-fixture-shaped-client',
      'redirect_uri': authCallbackRedirectUri,
      'scope': _fakeScopes.join(' '),
      'state': state,
      'code_challenge': pkce.challenge,
      'code_challenge_method': 'S256',
    });

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
    // Aynı bekleyen isteğin ikinci kez kullanılmasını engelle (her
    // completeSignIn denemesi taze bir beginSignIn gerektirir).
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

    final tokens = _issueTokens(user: _fakeUser);
    await _tokenStore.write(tokens);
    _emit(AuthSessionState.authenticated(tokens.user));
  }

  @override
  Future<void> refresh() async {
    final stored = await _tokenStore.read();
    if (stored == null) {
      throw const AuthNotAuthenticatedException();
    }
    // Rotasyon: yeni token seti tek bir `write()` ile eskisinin yerine
    // ATOMIK olarak geçer (bkz. ADR-039 — `clear()` + `write()` iki adımlı
    // sırayla YAPILMAZ).
    final rotated = _issueTokens(user: stored.user);
    await _tokenStore.write(rotated);
    _emit(AuthSessionState.authenticated(rotated.user));
  }

  @override
  Future<void> logout() async {
    await _tokenStore.clear();
    _emit(const AuthSessionState.anonymous());
  }

  AuthTokenResponse _issueTokens({required AuthUser user}) {
    return AuthTokenResponse(
      schemaVersion: kSchemaVersion,
      tokenType: 'Bearer',
      accessToken: 'fake-access-token-${_opaqueToken()}',
      expiresIn: 900,
      refreshToken: 'fake-refresh-token-${_opaqueToken()}',
      scope: _fakeScopes,
      user: user,
    );
  }

  @override
  void dispose() {
    _stateController.close();
  }
}
