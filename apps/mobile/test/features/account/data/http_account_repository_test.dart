import 'dart:convert';

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
  _FakeAuthRepository({required this.tokenStore, this.refreshShouldFail = false});

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
    test(
      'süresi dolmuş token 401 dönerse BİR KEZ refresh edilip istek '
      'YENİ tokenla tekrarlanır',
      () async {
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
        expect(sentTokens, [
          'Bearer eski-token',
          'Bearer yenilenmis-token',
        ]);
      },
    );

    test(
      'yenileme de başarısız olursa ORİJİNAL sunucu hatası yüzeye çıkar, '
      'sahte başarı üretilmez',
      () async {
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
      },
    );

    test(
      'süresi dolmayla İLGİSİZ bir hata (ör. service_unavailable) '
      'yenileme DENENMEDEN olduğu gibi yüzeye çıkar',
      () async {
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
      },
    );

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
    test(
      'hesap silme zorunlu Idempotency-Key header\'ı ve sabit '
      'confirmation gönderir',
      () async {
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
      },
    );

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
}
