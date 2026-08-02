import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:panelya_mobile/core/api/api_client.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/core/storage/token_store.dart';
import 'package:panelya_mobile/features/auth/domain/auth_repository.dart';
import 'package:panelya_mobile/features/auth/domain/auth_session_state.dart';
import 'package:panelya_mobile/features/progress/data/http_reading_progress_repository.dart';
import 'package:panelya_mobile/features/progress/domain/remote_reading_progress_exceptions.dart';

const _apiOrigin = 'https://api.panelya.invalid';
const _fixturesDir = '../../packages/contracts/fixtures';

String _fixture(String name) => File('$_fixturesDir/$name').readAsStringSync();

const _user = AuthUser(
  id: 'user-1',
  displayName: 'Ece',
  email: 'ece@example.invalid',
  emailVerified: true,
  role: 'reader',
);

AuthTokenResponse _tokens(String accessToken) => AuthTokenResponse(
  schemaVersion: kSchemaVersion,
  tokenType: 'Bearer',
  accessToken: accessToken,
  expiresIn: 900,
  refreshToken: 'refresh-1',
  scope: const ['openid'],
  user: _user,
);

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.tokenStore);

  final TokenStore tokenStore;
  int refreshCalls = 0;

  @override
  Future<void> refresh() async {
    refreshCalls++;
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

http.Response _json(String body, {int status = 200}) =>
    http.Response(body, status, headers: {'content-type': 'application/json'});

void main() {
  test('fetchProgress -> GET /api/progress + Bearer (cookie YOK)', () async {
    final tokenStore = InMemoryTokenStore();
    await tokenStore.write(_tokens('token'));
    String? method;
    String? path;
    String? auth;
    final client = PanelyaApiClient(
      apiOrigin: _apiOrigin,
      httpClient: MockClient((request) async {
        method = request.method;
        path = request.url.path;
        auth = request.headers['Authorization'];
        return _json(_fixture('reading-progress-response.v1.json'));
      }),
    );
    final repository = HttpReadingProgressRepository(
      client: client,
      tokenStore: tokenStore,
      authRepository: _FakeAuthRepository(tokenStore),
    );

    final response = await repository.fetchProgress();

    expect(method, 'GET');
    expect(path, '/api/progress');
    expect(auth, 'Bearer token');
    expect(response.items, hasLength(1));
  });

  test('upsertProgress -> POST + hedef durumun TAMAMI (delta DEĞİL)', () async {
    final tokenStore = InMemoryTokenStore();
    await tokenStore.write(_tokens('token'));
    Map<String, dynamic>? body;
    final client = PanelyaApiClient(
      apiOrigin: _apiOrigin,
      httpClient: MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return _json(_fixture('reading-progress-mutation-response.v1.json'));
      }),
    );
    final repository = HttpReadingProgressRepository(
      client: client,
      tokenStore: tokenStore,
      authRepository: _FakeAuthRepository(tokenStore),
    );

    await repository.upsertProgress(
      seriesSlug: 'gece-vardiyasi',
      episodeSlug: 'bolum-2',
      percent: 64,
    );

    expect(body, {
      'seriesSlug': 'gece-vardiyasi',
      'episodeSlug': 'bolum-2',
      'percent': 64,
    });
  });

  test(
    'ANONİM kullanıcı /api/progress ÇAĞIRMAZ — sunucuya hiç istek gitmez',
    () async {
      final tokenStore = InMemoryTokenStore();
      var requestCount = 0;
      final client = PanelyaApiClient(
        apiOrigin: _apiOrigin,
        httpClient: MockClient((request) async {
          requestCount++;
          return _json(_fixture('reading-progress-response.v1.json'));
        }),
      );
      final repository = HttpReadingProgressRepository(
        client: client,
        tokenStore: tokenStore,
        authRepository: _FakeAuthRepository(tokenStore),
      );

      await expectLater(
        repository.fetchProgress(),
        throwsA(isA<ReadingProgressNotAuthenticatedException>()),
      );
      await expectLater(
        repository.upsertProgress(
          seriesSlug: 's',
          episodeSlug: 'e',
          percent: 10,
        ),
        throwsA(isA<ReadingProgressNotAuthenticatedException>()),
      );
      expect(requestCount, 0);
    },
  );

  test('süresi dolmuş token BİR KEZ yenilenip istek tekrarlanır', () async {
    final tokenStore = InMemoryTokenStore();
    await tokenStore.write(_tokens('eski-token'));
    final authRepository = _FakeAuthRepository(tokenStore);
    final sent = <String?>[];
    final client = PanelyaApiClient(
      apiOrigin: _apiOrigin,
      httpClient: MockClient((request) async {
        sent.add(request.headers['Authorization']);
        return sent.length == 1
            ? _json(_fixture('reading-progress-error.v1.json'), status: 401)
            : _json(_fixture('reading-progress-response.v1.json'));
      }),
    );
    final repository = HttpReadingProgressRepository(
      client: client,
      tokenStore: tokenStore,
      authRepository: authRepository,
    );

    await repository.fetchProgress();

    expect(authRepository.refreshCalls, 1);
    expect(sent, ['Bearer eski-token', 'Bearer yenilenmis-token']);
  });

  test('structured hata KENDİ tipiyle ayrıştırılır (hesap/kütüphane DTO\'su '
      'kullanılmaz)', () async {
    final tokenStore = InMemoryTokenStore();
    await tokenStore.write(_tokens('token'));
    final client = PanelyaApiClient(
      apiOrigin: _apiOrigin,
      httpClient: MockClient((request) async {
        return _json(
          jsonEncode({
            'schemaVersion': kSchemaVersion,
            'error': 'rate_limited',
            'errorDescription': 'Çok fazla istek gönderdin.',
            'retryAfterSeconds': 30,
          }),
          status: 429,
        );
      }),
    );
    final repository = HttpReadingProgressRepository(
      client: client,
      tokenStore: tokenStore,
      authRepository: _FakeAuthRepository(tokenStore),
    );

    await expectLater(
      repository.fetchProgress(),
      throwsA(
        isA<ReadingProgressServerException>()
            .having((e) => e.error.error, 'error', 'rate_limited')
            .having((e) => e.error.retryAfterSeconds, 'retryAfter', 30)
            .having((e) => e.message, 'message', 'Çok fazla istek gönderdin.'),
      ),
    );
  });

  test('sunucunun verdiği SIRA korunur', () async {
    final tokenStore = InMemoryTokenStore();
    await tokenStore.write(_tokens('token'));
    final base =
        jsonDecode(_fixture('reading-progress-response.v1.json'))
            as Map<String, dynamic>;
    final item = (base['items'] as List).first as Map<String, dynamic>;

    Map<String, dynamic> withSlug(String slug, String updatedAt) {
      final copy = jsonDecode(jsonEncode(item)) as Map<String, dynamic>;
      (copy['series'] as Map<String, dynamic>)['slug'] = slug;
      copy['updatedAt'] = updatedAt;
      return copy;
    }

    final client = PanelyaApiClient(
      apiOrigin: _apiOrigin,
      httpClient: MockClient((request) async {
        return _json(
          jsonEncode({
            'schemaVersion': kSchemaVersion,
            'items': [
              withSlug('en-eski', '2020-01-01T00:00:00.000Z'),
              withSlug('en-yeni', '2030-01-01T00:00:00.000Z'),
            ],
          }),
        );
      }),
    );
    final repository = HttpReadingProgressRepository(
      client: client,
      tokenStore: tokenStore,
      authRepository: _FakeAuthRepository(tokenStore),
    );

    final response = await repository.fetchProgress();

    expect(response.items.map((i) => i.series.slug).toList(), [
      'en-eski',
      'en-yeni',
    ]);
  });
}
