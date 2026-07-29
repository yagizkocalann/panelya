import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:panelya_mobile/core/api/api_client.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/core/storage/token_store.dart';
import 'package:panelya_mobile/features/auth/data/http_auth_repository.dart';
import 'package:panelya_mobile/features/auth/domain/auth_exceptions.dart';
import 'package:panelya_mobile/features/auth/domain/auth_session_state.dart';

const _apiOrigin = 'https://api.panelya.invalid';

/// Bekleyen bir `unawaited(_restoreSession())` görevinin (bkz.
/// `HttpAuthRepository`'nin kurucusu) microtask kuyruğunu boşaltmasına izin
/// verir (aynı desen: `auth_providers_test.dart`).
Future<void> _flushMicrotasks() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Map<String, dynamic> _configJson() => {
  'schemaVersion': kSchemaVersion,
  'provider': 'auth0',
  'flow': 'authorization_code_pkce',
  'issuer': 'https://panelya.eu.auth0.com/',
  'clientId': 'mobile-client-id',
  'audience': 'https://api.panelya.app',
  'scopes': ['openid', 'profile', 'email', 'offline_access'],
  'authorizationEndpoint': 'https://panelya.eu.auth0.com/authorize',
  'tokenEndpoint': 'https://panelya.eu.auth0.com/oauth/token',
  'revocationEndpoint': 'https://panelya.eu.auth0.com/oauth/revoke',
  'accessTokenLifetimeSeconds': 900,
  'refreshTokenRotation': true,
};

Map<String, dynamic> _userJson({String id = 'user-1'}) => {
  'id': id,
  'displayName': 'Ada Lovelace',
  'email': 'ada@example.com',
  'emailVerified': true,
  'role': 'reader',
};

Map<String, dynamic> _tokenJson({
  String accessToken = 'access-1',
  String refreshToken = 'refresh-1',
  String userId = 'user-1',
}) => {
  'schemaVersion': kSchemaVersion,
  'tokenType': 'Bearer',
  'accessToken': accessToken,
  'expiresIn': 900,
  'refreshToken': refreshToken,
  'scope': ['openid', 'profile'],
  'user': _userJson(id: userId),
};

Map<String, dynamic> _stateJson({bool authenticated = true, String? userId = 'user-1'}) => {
  'schemaVersion': kSchemaVersion,
  'authenticated': authenticated,
  'user': authenticated && userId != null ? _userJson(id: userId) : null,
};

Map<String, dynamic> _errorJson(String error, {bool reauthenticate = false}) => {
  'schemaVersion': kSchemaVersion,
  'error': error,
  'errorDescription': 'test error: $error',
  'reauthenticate': reauthenticate,
};

http.Response _json(Map<String, dynamic> body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

typedef _Handler = Future<http.Response> Function(http.Request request);

PanelyaApiClient _clientWith(_Handler handler) {
  return PanelyaApiClient(
    apiOrigin: _apiOrigin,
    httpClient: MockClient((request) => handler(request)),
  );
}

/// Her zaman "beklenmeyen istek" ile çöken bir istemci — yalnız hiç ağ
/// isteği yapılmaması gereken testlerde (bkz. "kurucu: saklı oturum yok")
/// kullanılır.
PanelyaApiClient _unreachableClient() {
  return _clientWith((request) async {
    fail('Beklenmeyen HTTP isteği: ${request.method} ${request.url}');
  });
}

void main() {
  group('HttpAuthRepository.beginSignIn', () {
    test(
      '/api/auth/config hata döndürürse AuthProviderErrorException fırlatır',
      () async {
        final client = _clientWith((request) async {
          expect(request.url.path, '/api/auth/config');
          return _json(_errorJson('service_unavailable'), status: 503);
        });
        final repo = HttpAuthRepository(client: client, tokenStore: InMemoryTokenStore());
        addTearDown(repo.dispose);
        await _flushMicrotasks();

        await expectLater(
          repo.beginSignIn(),
          throwsA(isA<AuthProviderErrorException>()),
        );
      },
    );

    test(
      'başarılı config: authorizationUrl PKCE S256, panelya callback ve '
      'ui_locales=tr taşır',
      () async {
        final client = _clientWith((request) async {
          expect(request.url.path, '/api/auth/config');
          return _json(_configJson());
        });
        final repo = HttpAuthRepository(client: client, tokenStore: InMemoryTokenStore());
        addTearDown(repo.dispose);
        await _flushMicrotasks();

        final authRequest = await repo.beginSignIn();
        final params = authRequest.authorizationUrl.queryParameters;

        expect(params['response_type'], 'code');
        expect(params['client_id'], 'mobile-client-id');
        expect(params['redirect_uri'], 'panelya://auth/callback');
        expect(params['audience'], 'https://api.panelya.app');
        expect(params['scope'], 'openid profile email offline_access');
        expect(params['code_challenge_method'], 'S256');
        expect(params['ui_locales'], 'tr');
        expect(params['state'], isNotEmpty);
        expect(params['code_challenge'], isNotEmpty);
        expect(authRequest.callbackUrlScheme, 'panelya');
      },
    );
  });

  group('HttpAuthRepository.completeSignIn', () {
    test(
      'başarılı akış: kod/verifier değişimi + /api/auth/me doğrulaması '
      'sonrası authenticated durumuna geçer ve tokenları saklar',
      () async {
        final tokenStore = InMemoryTokenStore();
        Map<String, dynamic>? tokenRequestBody;
        String? meAuthorizationHeader;

        final client = _clientWith((request) async {
          switch (request.url.path) {
            case '/api/auth/config':
              return _json(_configJson());
            case '/api/auth/mobile/token':
              tokenRequestBody = jsonDecode(request.body) as Map<String, dynamic>;
              return _json(_tokenJson(accessToken: 'issued-access'));
            case '/api/auth/me':
              meAuthorizationHeader = request.headers['Authorization'];
              return _json(_stateJson());
            default:
              fail('Beklenmeyen istek: ${request.url}');
          }
        });
        final repo = HttpAuthRepository(client: client, tokenStore: tokenStore);
        addTearDown(repo.dispose);
        await _flushMicrotasks();

        final authRequest = await repo.beginSignIn();
        final state = authRequest.authorizationUrl.queryParameters['state']!;
        await repo.completeSignIn(
          Uri.parse('panelya://auth/callback?code=abc123&state=$state'),
        );

        expect(repo.currentState, isA<AuthAuthenticated>());
        expect((await tokenStore.read())!.accessToken, 'issued-access');
        expect(tokenRequestBody!['grantType'], 'authorization_code');
        expect(tokenRequestBody!['authorizationCode'], 'abc123');
        expect(tokenRequestBody!['redirectUri'], 'panelya://auth/callback');
        expect(meAuthorizationHeader, 'Bearer issued-access');
      },
    );

    test(
      '/api/auth/me yeni tokeni "authenticated: false" olarak doğrularsa '
      'oturum GÖSTERİLMEZ, token da saklanmaz (ikinci doğrulama katmanı)',
      () async {
        final tokenStore = InMemoryTokenStore();
        final client = _clientWith((request) async {
          switch (request.url.path) {
            case '/api/auth/config':
              return _json(_configJson());
            case '/api/auth/mobile/token':
              return _json(_tokenJson());
            case '/api/auth/me':
              return _json(_stateJson(authenticated: false, userId: null));
            default:
              fail('Beklenmeyen istek: ${request.url}');
          }
        });
        final repo = HttpAuthRepository(client: client, tokenStore: tokenStore);
        addTearDown(repo.dispose);
        await _flushMicrotasks();

        final authRequest = await repo.beginSignIn();
        final state = authRequest.authorizationUrl.queryParameters['state']!;

        await expectLater(
          repo.completeSignIn(
            Uri.parse('panelya://auth/callback?code=abc&state=$state'),
          ),
          throwsA(isA<AuthProviderErrorException>()),
        );
        expect(await tokenStore.read(), isNull);
        expect(repo.currentState, const AuthSessionState.anonymous());
      },
    );

    test(
      'sağlayıcı error=access_denied döndürürse AuthUserCancelledException '
      'fırlatır (kullanıcı iptali, sağlayıcı hatası değil)',
      () async {
        final client = _clientWith((request) async {
          expect(request.url.path, '/api/auth/config');
          return _json(_configJson());
        });
        final repo = HttpAuthRepository(client: client, tokenStore: InMemoryTokenStore());
        addTearDown(repo.dispose);
        await _flushMicrotasks();

        final authRequest = await repo.beginSignIn();
        final state = authRequest.authorizationUrl.queryParameters['state']!;

        await expectLater(
          repo.completeSignIn(
            Uri.parse('panelya://auth/callback?error=access_denied&state=$state'),
          ),
          throwsA(isA<AuthUserCancelledException>()),
        );
      },
    );

    test(
      'state parametresi uyuşmuyorsa (CSRF) AuthCallbackException fırlatır '
      've hiçbir ağ isteği (token değişimi) yapmaz',
      () async {
        final client = _clientWith((request) async {
          expect(request.url.path, '/api/auth/config');
          return _json(_configJson());
        });
        final repo = HttpAuthRepository(client: client, tokenStore: InMemoryTokenStore());
        addTearDown(repo.dispose);
        await _flushMicrotasks();

        await repo.beginSignIn();

        await expectLater(
          repo.completeSignIn(
            Uri.parse('panelya://auth/callback?code=abc&state=wrong-state'),
          ),
          throwsA(isA<AuthCallbackException>()),
        );
      },
    );
  });

  group('HttpAuthRepository.refresh', () {
    test('aktif oturum yokken AuthNotAuthenticatedException fırlatır', () async {
      final repo = HttpAuthRepository(client: _unreachableClient(), tokenStore: InMemoryTokenStore());
      addTearDown(repo.dispose);
      await _flushMicrotasks();

      await expectLater(repo.refresh(), throwsA(isA<AuthNotAuthenticatedException>()));
    });

    test(
      'başarılı yenileme: yeni token setini TEK write() ile atomik olarak '
      'yazar ve authenticated durumuna geçer',
      () async {
        final tokenStore = InMemoryTokenStore();
        final client = _clientWith((request) async {
          expect(request.url.path, '/api/auth/mobile/token');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['grantType'], 'refresh_token');
          expect(body['refreshToken'], 'old-refresh');
          return _json(_tokenJson(accessToken: 'new-access', refreshToken: 'new-refresh'));
        });
        final repo = HttpAuthRepository(client: client, tokenStore: tokenStore);
        addTearDown(repo.dispose);
        await _flushMicrotasks();
        await tokenStore.write(
          AuthTokenResponse.fromJson(
            _tokenJson(accessToken: 'old-access', refreshToken: 'old-refresh'),
          ),
        );

        await repo.refresh();

        expect(repo.currentState, isA<AuthAuthenticated>());
        expect((await tokenStore.read())!.accessToken, 'new-access');
        expect((await tokenStore.read())!.refreshToken, 'new-refresh');
      },
    );

    test(
      'token_reused gibi reauthenticate hatası: token temizlenir, anonime '
      'döner ve hata da yükselir',
      () async {
        final tokenStore = InMemoryTokenStore();
        final client = _clientWith((request) async {
          expect(request.url.path, '/api/auth/mobile/token');
          return _json(_errorJson('token_reused', reauthenticate: true), status: 400);
        });
        final repo = HttpAuthRepository(client: client, tokenStore: tokenStore);
        addTearDown(repo.dispose);
        await _flushMicrotasks();
        await tokenStore.write(AuthTokenResponse.fromJson(_tokenJson()));

        await expectLater(repo.refresh(), throwsA(isA<AuthProviderErrorException>()));
        expect(repo.currentState, const AuthSessionState.anonymous());
        expect(await tokenStore.read(), isNull);
      },
    );

    test(
      'rate_limited gibi reauthenticate OLMAYAN bir hata: token SİLİNMEZ '
      '(geçici hata, oturum kaybedilmez)',
      () async {
        final tokenStore = InMemoryTokenStore();
        final client = _clientWith((request) async {
          expect(request.url.path, '/api/auth/mobile/token');
          return _json(_errorJson('rate_limited'), status: 429);
        });
        final repo = HttpAuthRepository(client: client, tokenStore: tokenStore);
        addTearDown(repo.dispose);
        await _flushMicrotasks();
        await tokenStore.write(AuthTokenResponse.fromJson(_tokenJson()));

        await expectLater(repo.refresh(), throwsA(isA<AuthProviderErrorException>()));
        expect(await tokenStore.read(), isNotNull);
      },
    );
  });

  group('HttpAuthRepository.logout', () {
    test('aktif oturum yokken no-op olarak anonim kalır', () async {
      final repo = HttpAuthRepository(client: _unreachableClient(), tokenStore: InMemoryTokenStore());
      addTearDown(repo.dispose);
      await _flushMicrotasks();

      await repo.logout();
      expect(repo.currentState, const AuthSessionState.anonymous());
    });

    test(
      'sağlayıcı revoke isteği başarısız olsa bile yerel oturum temizlenir '
      '(ADR-039: tekrar da başarılı sayılır)',
      () async {
        final tokenStore = InMemoryTokenStore();
        final client = _clientWith((request) async {
          expect(request.url.path, '/api/auth/mobile/revoke');
          return _json(_errorJson('service_unavailable'), status: 503);
        });
        final repo = HttpAuthRepository(client: client, tokenStore: tokenStore);
        addTearDown(repo.dispose);
        await _flushMicrotasks();
        await tokenStore.write(AuthTokenResponse.fromJson(_tokenJson()));

        await repo.logout();

        expect(repo.currentState, const AuthSessionState.anonymous());
        expect(await tokenStore.read(), isNull);
      },
    );
  });

  group('HttpAuthRepository — uygulama açılışında oturum geri yükleme', () {
    test(
      'saklı oturum yoksa kurucu hiçbir ağ isteği yapmadan anonim kalır',
      () async {
        final repo = HttpAuthRepository(client: _unreachableClient(), tokenStore: InMemoryTokenStore());
        addTearDown(repo.dispose);

        await _flushMicrotasks();

        expect(repo.currentState, const AuthSessionState.anonymous());
      },
    );

    test(
      'saklı geçerli oturum /api/auth/me ile doğrulanır ve sessizce '
      'authenticated durumuna geçer',
      () async {
        final tokenStore = InMemoryTokenStore();
        await tokenStore.write(
          AuthTokenResponse.fromJson(_tokenJson(accessToken: 'stored-access')),
        );
        final client = _clientWith((request) async {
          expect(request.url.path, '/api/auth/me');
          expect(request.headers['Authorization'], 'Bearer stored-access');
          return _json(_stateJson());
        });

        final repo = HttpAuthRepository(client: client, tokenStore: tokenStore);
        addTearDown(repo.dispose);

        expect(repo.currentState, const AuthSessionState.anonymous());
        await _flushMicrotasks();

        expect(repo.currentState, isA<AuthAuthenticated>());
      },
    );

    test(
      'token_expired: refresh() otomatik denenir, yeni tokenlarla '
      'authenticated durumuna geçilir',
      () async {
        final tokenStore = InMemoryTokenStore();
        await tokenStore.write(
          AuthTokenResponse.fromJson(
            _tokenJson(accessToken: 'expired-access', refreshToken: 'refresh-1'),
          ),
        );
        var meCalls = 0;
        final client = _clientWith((request) async {
          switch (request.url.path) {
            case '/api/auth/me':
              meCalls++;
              return _json(_errorJson('token_expired', reauthenticate: true), status: 401);
            case '/api/auth/mobile/token':
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['grantType'], 'refresh_token');
              expect(body['refreshToken'], 'refresh-1');
              return _json(_tokenJson(accessToken: 'new-access', refreshToken: 'new-refresh'));
            default:
              fail('Beklenmeyen istek: ${request.url}');
          }
        });

        final repo = HttpAuthRepository(client: client, tokenStore: tokenStore);
        addTearDown(repo.dispose);
        await _flushMicrotasks();

        expect(repo.currentState, isA<AuthAuthenticated>());
        expect((await tokenStore.read())!.accessToken, 'new-access');
        expect(meCalls, 1);
      },
    );

    test(
      'session_revoked ve refresh de reauthenticate hatası verirse: token '
      'temizlenir, anonim kalır',
      () async {
        final tokenStore = InMemoryTokenStore();
        await tokenStore.write(AuthTokenResponse.fromJson(_tokenJson()));
        final client = _clientWith((request) async {
          switch (request.url.path) {
            case '/api/auth/me':
              return _json(_errorJson('session_revoked', reauthenticate: true), status: 401);
            case '/api/auth/mobile/token':
              return _json(_errorJson('token_reused', reauthenticate: true), status: 400);
            default:
              fail('Beklenmeyen istek: ${request.url}');
          }
        });

        final repo = HttpAuthRepository(client: client, tokenStore: tokenStore);
        addTearDown(repo.dispose);
        await _flushMicrotasks();

        expect(repo.currentState, const AuthSessionState.anonymous());
        expect(await tokenStore.read(), isNull);
      },
    );

    test(
      'service_unavailable gibi GEÇİCİ bir hata: token SİLİNMEZ, oturum '
      'sahte olarak da GÖSTERİLMEZ — sonraki denemeye bırakılır',
      () async {
        final tokenStore = InMemoryTokenStore();
        await tokenStore.write(AuthTokenResponse.fromJson(_tokenJson()));
        final client = _clientWith((request) async {
          expect(request.url.path, '/api/auth/me');
          return _json(_errorJson('service_unavailable'), status: 503);
        });

        final repo = HttpAuthRepository(client: client, tokenStore: tokenStore);
        addTearDown(repo.dispose);
        await _flushMicrotasks();

        expect(repo.currentState, const AuthSessionState.anonymous());
        expect(await tokenStore.read(), isNotNull);
      },
    );
  });
}
