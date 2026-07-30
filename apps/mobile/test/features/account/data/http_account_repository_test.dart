import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:panelya_mobile/core/api/api_client.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/core/storage/token_store.dart';
import 'package:panelya_mobile/features/account/data/http_account_repository.dart';
import 'package:panelya_mobile/features/account/domain/account_exceptions.dart';
import 'package:panelya_mobile/features/auth/domain/auth_repository.dart';
import 'package:panelya_mobile/features/auth/domain/auth_session_state.dart';

const _apiOrigin = 'https://api.panelya.invalid';

const _user = AuthUser(
  id: 'user-1',
  displayName: 'Ece Yılmaz',
  email: 'ece@example.invalid',
  emailVerified: true,
  role: 'reader',
);

AuthTokenResponse _tokens(String accessToken) => const AuthTokenResponse(
  schemaVersion: kSchemaVersion,
  tokenType: 'Bearer',
  accessToken: '',
  expiresIn: 900,
  refreshToken: 'refresh-1',
  scope: ['openid'],
  user: _user,
).copyWithAccessToken(accessToken);

extension _TokenCopy on AuthTokenResponse {
  AuthTokenResponse copyWithAccessToken(String value) => AuthTokenResponse(
    schemaVersion: schemaVersion,
    tokenType: tokenType,
    accessToken: value,
    expiresIn: expiresIn,
    refreshToken: refreshToken,
    scope: scope,
    user: user,
  );
}

/// `refresh()` çağrıldığında [TokenStore]'a YENİ bir access token yazar —
/// gerçek `HttpAuthRepository`nin rotasyon davranışının minimal taklidi.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    required this.tokenStore,
    this.refreshShouldFail = false,
  });

  final TokenStore tokenStore;
  final bool refreshShouldFail;
  int refreshCalls = 0;

  @override
  Future<void> refresh() async {
    refreshCalls++;
    if (refreshShouldFail) throw Exception('refresh failed');
    await tokenStore.write(_tokens('yenilenmis-token'));
  }

  @override
  AuthSessionState get currentState =>
      const AuthSessionState.authenticated(_user);

  @override
  Stream<AuthSessionState> get stateChanges => Stream.value(currentState);

  @override
  Future<AuthorizationRequest> beginSignIn() => throw UnimplementedError();

  @override
  Future<void> completeSignIn(Uri callbackUri) => throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  void dispose() {}
}

http.Response _expiredTokenResponse() => http.Response(
  jsonEncode({
    'schemaVersion': '1.0',
    'error': 'not_authenticated',
    'errorDescription': 'Access token expired.',
    'reauthenticate': true,
  }),
  401,
  headers: {'content-type': 'application/json'},
);

http.Response _overviewResponse() => http.Response(
  jsonEncode({
    'schemaVersion': '1.0',
    'user': {
      'id': 'user-1',
      'displayName': 'Ece Yılmaz',
      'email': 'ece@example.invalid',
      'emailVerified': true,
      'role': 'reader',
    },
    'provider': 'database',
    'capabilities': {
      'profileEditing': 'enabled',
      'avatarEditing': 'unavailable',
      'emailChange': 'reauthentication_required',
      'passwordAction': 'enabled',
      'sessionManagement': 'enabled',
      'blockedAccounts': 'enabled',
      'accountDeletion': 'reauthentication_required',
    },
  }),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('HttpAccountRepository — access token yenileme', () {
    test('süresi dolmuş token 401 dönerse BİR KEZ refresh edilip istek '
        'YENİ tokenla tekrarlanır', () async {
      final tokenStore = InMemoryTokenStore();
      await tokenStore.write(_tokens('eski-token'));
      final authRepository = _FakeAuthRepository(tokenStore: tokenStore);

      final sentTokens = <String?>[];
      final client = PanelyaApiClient(
        apiOrigin: _apiOrigin,
        httpClient: MockClient((request) async {
          sentTokens.add(request.headers['Authorization']);
          // İlk istek süresi dolmuş tokenla gelir; ikincisi yenisiyle.
          return sentTokens.length == 1
              ? _expiredTokenResponse()
              : _overviewResponse();
        }),
      );

      final repository = HttpAccountRepository(
        client: client,
        tokenStore: tokenStore,
        authRepository: authRepository,
      );

      final overview = await repository.fetchOverview();

      expect(overview.user.id, 'user-1');
      expect(authRepository.refreshCalls, 1);
      expect(sentTokens, ['Bearer eski-token', 'Bearer yenilenmis-token']);
    });

    test('yenileme de başarısız olursa ORİJİNAL sunucu hatası yüzeye çıkar, '
        'sahte başarı üretilmez', () async {
      final tokenStore = InMemoryTokenStore();
      await tokenStore.write(_tokens('eski-token'));
      final authRepository = _FakeAuthRepository(
        tokenStore: tokenStore,
        refreshShouldFail: true,
      );

      var requestCount = 0;
      final client = PanelyaApiClient(
        apiOrigin: _apiOrigin,
        httpClient: MockClient((request) async {
          requestCount++;
          return _expiredTokenResponse();
        }),
      );

      final repository = HttpAccountRepository(
        client: client,
        tokenStore: tokenStore,
        authRepository: authRepository,
      );

      await expectLater(
        repository.fetchOverview(),
        throwsA(
          isA<AccountServerException>().having(
            (e) => e.error.error,
            'error.error',
            'not_authenticated',
          ),
        ),
      );
      expect(authRepository.refreshCalls, 1);
      // Yenileme başarısız olduğu için istek TEKRARLANMAZ.
      expect(requestCount, 1);
    });

    test('süresi dolmayla İLGİSİZ bir hata (ör. service_unavailable) '
        'yenileme DENENMEDEN olduğu gibi yüzeye çıkar', () async {
      final tokenStore = InMemoryTokenStore();
      await tokenStore.write(_tokens('eski-token'));
      final authRepository = _FakeAuthRepository(tokenStore: tokenStore);

      var requestCount = 0;
      final client = PanelyaApiClient(
        apiOrigin: _apiOrigin,
        httpClient: MockClient((request) async {
          requestCount++;
          return http.Response(
            jsonEncode({
              'schemaVersion': '1.0',
              'error': 'service_unavailable',
              'errorDescription': 'Oturum servisi kullanilamiyor.',
              'reauthenticate': false,
            }),
            503,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final repository = HttpAccountRepository(
        client: client,
        tokenStore: tokenStore,
        authRepository: authRepository,
      );

      await expectLater(
        repository.revokeSessions(scope: 'others'),
        throwsA(
          isA<AccountServerException>().having(
            (e) => e.isServiceUnavailable,
            'isServiceUnavailable',
            isTrue,
          ),
        ),
      );
      expect(authRepository.refreshCalls, 0);
      expect(requestCount, 1);
    });

    test('saklı oturum yoksa sunucuya HİÇ istek gönderilmez', () async {
      final tokenStore = InMemoryTokenStore();
      final authRepository = _FakeAuthRepository(tokenStore: tokenStore);

      var requestCount = 0;
      final client = PanelyaApiClient(
        apiOrigin: _apiOrigin,
        httpClient: MockClient((request) async {
          requestCount++;
          return _overviewResponse();
        }),
      );

      final repository = HttpAccountRepository(
        client: client,
        tokenStore: tokenStore,
        authRepository: authRepository,
      );

      await expectLater(
        repository.fetchOverview(),
        throwsA(isA<AccountNotAuthenticatedException>()),
      );
      expect(requestCount, 0);
    });
  });

  group('HttpAccountRepository — sözleşme ayrıntıları', () {
    test('hesap silme zorunlu Idempotency-Key header\'ı ve sabit '
        'confirmation gönderir', () async {
      final tokenStore = InMemoryTokenStore();
      await tokenStore.write(_tokens('token'));
      final authRepository = _FakeAuthRepository(tokenStore: tokenStore);

      String? idempotencyKey;
      Map<String, dynamic>? body;
      final client = PanelyaApiClient(
        apiOrigin: _apiOrigin,
        httpClient: MockClient((request) async {
          idempotencyKey = request.headers['Idempotency-Key'];
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'schemaVersion': '1.0',
              'requestId': 'deletion-request-0001',
              'status': 'pending',
            }),
            202,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final repository = HttpAccountRepository(
        client: client,
        tokenStore: tokenStore,
        authRepository: authRepository,
      );

      final result = await repository.deleteAccount(
        reauthenticationToken: 'reauth-token-0000000000000000000000000',
      );

      expect(idempotencyKey, isNotNull);
      // Sözleşme 16–128 karakter ister.
      expect(idempotencyKey!.length, greaterThanOrEqualTo(16));
      expect(idempotencyKey!.length, lessThanOrEqualTo(128));
      expect(body!['confirmation'], 'delete_my_account');
      expect(
        body!['reauthenticationToken'],
        'reauth-token-0000000000000000000000000',
      );
      // Asenkron silme dürüstçe raporlanır.
      expect(result.status, 'pending');
    });

    test(
      'reauthentication start isteği S256 sabitini ve amacı gönderir',
      () async {
        final tokenStore = InMemoryTokenStore();
        await tokenStore.write(_tokens('token'));
        final authRepository = _FakeAuthRepository(tokenStore: tokenStore);

        Map<String, dynamic>? body;
        final client = PanelyaApiClient(
          apiOrigin: _apiOrigin,
          httpClient: MockClient((request) async {
            body = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'schemaVersion': '1.0',
                'requestId': 'reauth-request-0001',
                'authorizationUrl': 'https://identity.invalid/authorize',
                'callbackUrlScheme': 'panelya',
                'expiresAt': '2030-01-01T12:05:00.000Z',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        final repository = HttpAccountRepository(
          client: client,
          tokenStore: tokenStore,
          authRepository: authRepository,
        );

        await repository.startReauthentication(
          purpose: AccountReauthenticationPurpose.email_change,
          redirectUri: 'panelya://auth/callback',
          codeChallenge: 'a' * 43,
        );

        expect(body!['purpose'], 'email_change');
        expect(body!['codeChallengeMethod'], 'S256');
        expect(body!['redirectUri'], 'panelya://auth/callback');
      },
    );
  });

  _wireContractTests();
}

/// Asagidaki testler adapter'in HER metodunun ortak sozlesmeye gore
/// dogru HTTP metodu, yolu ve gövdesini urettigini kilitler.
///
/// Bunlar canli QA'nin YERINE GECMEZ, onun ULASAMADIGI yeri kapatir:
/// `sessions` ve `password-reset` uclari yerel ortamda 503 fail-closed
/// donduğu icin gövde/yol dogrulugu canlida hic gorulemedi. Yanlis bir
/// alan adi ya da yol yalnizca production'da ortaya cikardi.
/// Yanit govdeleri ORTAK fixture'lardan okunur (tahmin edilmez): sozlesme
/// degisirse bu testler kendiliginden yakalar.
String _fixture(String name) =>
    File('../../packages/contracts/fixtures/$name').readAsStringSync();

void _wireContractTests() {
  group('HttpAccountRepository — sozlesme tel formati', () {
    late InMemoryTokenStore tokenStore;
    late _FakeAuthRepository authRepository;
    String? seenMethod;
    String? seenPath;
    Map<String, dynamic>? seenBody;

    HttpAccountRepository build(String responseJson, {int status = 200}) {
      tokenStore = InMemoryTokenStore();
      authRepository = _FakeAuthRepository(tokenStore: tokenStore);
      final client = PanelyaApiClient(
        apiOrigin: _apiOrigin,
        httpClient: MockClient((request) async {
          seenMethod = request.method;
          seenPath = request.url.path;
          seenBody = request.body.isEmpty
              ? null
              : jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            responseJson,
            status,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      return HttpAccountRepository(
        client: client,
        tokenStore: tokenStore,
        authRepository: authRepository,
      );
    }

    Future<void> seed() => tokenStore.write(_tokens('token'));

    test('updateProfile -> PATCH /api/account/profile + displayName', () async {
      final repo = build(
        jsonEncode({
          'schemaVersion': '1.0',
          'user': {
            'id': 'user-1',
            'displayName': 'Yeni Ad',
            'email': 'e@example.invalid',
            'emailVerified': true,
            'role': 'reader',
          },
          'provider': 'database',
          'capabilities': {
            'profileEditing': 'enabled',
            'avatarEditing': 'unavailable',
            'emailChange': 'enabled',
            'passwordAction': 'enabled',
            'sessionManagement': 'enabled',
            'blockedAccounts': 'enabled',
            'accountDeletion': 'enabled',
          },
        }),
      );
      await seed();

      final result = await repo.updateProfile(displayName: 'Yeni Ad');

      expect(seenMethod, 'PATCH');
      expect(seenPath, '/api/account/profile');
      expect(seenBody, {'displayName': 'Yeni Ad'});
      expect(result.user.displayName, 'Yeni Ad');
    });

    test('requestPasswordReset -> POST /api/account/password-reset', () async {
      final repo = build(_fixture('account-action-accepted.v1.json'));
      await seed();

      await repo.requestPasswordReset();

      expect(seenMethod, 'POST');
      expect(seenPath, '/api/account/password-reset');
      // Alansiz DTO: gövde bos bir JSON nesnesidir.
      expect(seenBody, isEmpty);
    });

    test('requestEmailChange -> POST /api/account/email-change + '
        'reauthenticationToken', () async {
      final repo = build(_fixture('account-action-accepted.v1.json'));
      await seed();

      await repo.requestEmailChange(
        newEmail: 'yeni@example.invalid',
        reauthenticationToken: 'reauth-token-000000000000000000000000',
      );

      expect(seenMethod, 'POST');
      expect(seenPath, '/api/account/email-change');
      expect(seenBody!['newEmail'], 'yeni@example.invalid');
      expect(
        seenBody!['reauthenticationToken'],
        'reauth-token-000000000000000000000000',
      );
    });

    test('fetchSessions -> GET /api/account/sessions', () async {
      final repo = build(_fixture('account-sessions.v1.json'));
      await seed();

      await repo.fetchSessions();

      expect(seenMethod, 'GET');
      expect(seenPath, '/api/account/sessions');
    });

    test('revokeSession -> oturum kimligi YOLA kodlanir', () async {
      final repo = build(
        _fixture('account-session-revocation-response.v1.json'),
      );
      await seed();

      await repo.revokeSession('oturum/kimlik');

      expect(seenMethod, 'DELETE');
      // Bolu isareti kacilmali; yoksa baska bir uca giderdi.
      expect(seenPath, '/api/account/sessions/oturum%2Fkimlik');
    });

    test('fetchBlockedAccounts -> GET /api/account/blocks', () async {
      final repo = build(_fixture('account-blocks.v1.json'));
      await seed();

      await repo.fetchBlockedAccounts();

      expect(seenMethod, 'GET');
      expect(seenPath, '/api/account/blocks');
    });

    test('unblockAccount -> kullanici kimligi YOLA kodlanir', () async {
      final repo = build(_fixture('account-action-accepted.v1.json'));
      await seed();

      await repo.unblockAccount('user id');

      expect(seenMethod, 'DELETE');
      expect(seenPath, '/api/account/blocks/user%20id');
    });

    test('fetchDeletionSummary -> GET /api/account/deletion', () async {
      final repo = build(_fixture('account-deletion-summary.v1.json'));
      await seed();

      await repo.fetchDeletionSummary();

      expect(seenMethod, 'GET');
      expect(seenPath, '/api/account/deletion');
    });

    test(
      'completeReauthentication -> code/state/verifier TAMAMI gonderilir',
      () async {
        final repo = build(
          _fixture('account-reauthentication-complete-response.v1.json'),
        );
        await seed();

        await repo.completeReauthentication(
          requestId: 'req-1',
          authorizationCode: 'code-1',
          state: 'state-1',
          codeVerifier: 'verifier-1',
          redirectUri: 'panelya://auth/callback',
        );

        expect(seenMethod, 'POST');
        expect(seenPath, '/api/account/reauthentication/complete');
        expect(seenBody!['requestId'], 'req-1');
        expect(seenBody!['authorizationCode'], 'code-1');
        expect(seenBody!['state'], 'state-1');
        expect(seenBody!['codeVerifier'], 'verifier-1');
        expect(seenBody!['redirectUri'], 'panelya://auth/callback');
      },
    );

    test('AG hatasi (sunucu yaniti YOK) AccountUnexpectedException olur — '
        'sunucu hatasiyla karistirilmaz', () async {
      tokenStore = InMemoryTokenStore();
      authRepository = _FakeAuthRepository(tokenStore: tokenStore);
      final client = PanelyaApiClient(
        apiOrigin: _apiOrigin,
        httpClient: MockClient((request) async {
          throw const SocketException('baglanti yok');
        }),
      );
      final repo = HttpAccountRepository(
        client: client,
        tokenStore: tokenStore,
        authRepository: authRepository,
      );
      await seed();

      await expectLater(
        repo.fetchOverview(),
        throwsA(isA<AccountUnexpectedException>()),
      );
    });

    test(
      'yenileme sonrasi TEKRAR sunucu hatasi gelirse ikinci hata yuzeye cikar',
      () async {
        tokenStore = InMemoryTokenStore();
        authRepository = _FakeAuthRepository(tokenStore: tokenStore);
        var call = 0;
        final client = PanelyaApiClient(
          apiOrigin: _apiOrigin,
          httpClient: MockClient((request) async {
            call++;
            if (call == 1) return _expiredTokenResponse();
            return http.Response(
              jsonEncode({
                'schemaVersion': '1.0',
                'error': 'forbidden',
                'errorDescription': 'Bu islem icin yetkin yok.',
                'reauthenticate': false,
              }),
              403,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        final repo = HttpAccountRepository(
          client: client,
          tokenStore: tokenStore,
          authRepository: authRepository,
        );
        await seed();

        await expectLater(
          repo.fetchOverview(),
          throwsA(
            isA<AccountServerException>().having(
              (e) => e.error.error,
              'error.error',
              // Ilk hata degil, TEKRAR denemenin hatasi bildirilir.
              'forbidden',
            ),
          ),
        );
        expect(authRepository.refreshCalls, 1);
        expect(call, 2);
      },
    );
  });
}
