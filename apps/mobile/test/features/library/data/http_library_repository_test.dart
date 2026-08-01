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
import 'package:panelya_mobile/features/library/data/http_library_repository.dart';
import 'package:panelya_mobile/features/library/domain/library_exceptions.dart';

const _apiOrigin = 'https://api.panelya.invalid';
const _fixturesDir = '../../packages/contracts/fixtures';

/// Yanıt gövdeleri ORTAK fixture'lardan okunur (tahmin edilmez).
String _fixture(String name) => File('$_fixturesDir/$name').readAsStringSync();

const _user = AuthUser(
  id: 'user-1',
  displayName: 'Ece Yılmaz',
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

http.Response _json(String body, {int status = 200}) =>
    http.Response(body, status, headers: {'content-type': 'application/json'});

void main() {
  late InMemoryTokenStore tokenStore;
  late _FakeAuthRepository authRepository;
  String? seenMethod;
  String? seenPath;
  String? seenAuthorization;
  Map<String, dynamic>? seenBody;

  HttpLibraryRepository build(
    String responseBody, {
    int status = 200,
    bool refreshShouldFail = false,
  }) {
    tokenStore = InMemoryTokenStore();
    authRepository = _FakeAuthRepository(
      tokenStore: tokenStore,
      refreshShouldFail: refreshShouldFail,
    );
    final client = PanelyaApiClient(
      apiOrigin: _apiOrigin,
      httpClient: MockClient((request) async {
        seenMethod = request.method;
        seenPath = request.url.path;
        seenAuthorization = request.headers['Authorization'];
        seenBody = request.body.isEmpty
            ? null
            : jsonDecode(request.body) as Map<String, dynamic>;
        return _json(responseBody, status: status);
      }),
    );
    return HttpLibraryRepository(
      client: client,
      tokenStore: tokenStore,
      authRepository: authRepository,
    );
  }

  Future<void> seed() => tokenStore.write(_tokens('token'));

  group('HttpLibraryRepository — sözleşme tel formatı', () {
    test('fetchLibrary -> GET /api/library + Bearer (cookie YOK)', () async {
      final repository = build(_fixture('library-response.v1.json'));
      await seed();

      final response = await repository.fetchLibrary();

      expect(seenMethod, 'GET');
      expect(seenPath, '/api/library');
      expect(seenAuthorization, 'Bearer token');
      expect(response.items, hasLength(1));
    });

    test('upsertEntry -> POST + hedef durumun TAMAMI (toggle DEĞİL)', () async {
      final repository = build(_fixture('library-mutation-response.v1.json'));
      await seed();

      await repository.upsertEntry(
        slug: 'gece-vardiyasi',
        status: LibraryStatus.completed,
        favorite: false,
      );

      expect(seenMethod, 'POST');
      expect(seenPath, '/api/library/gece-vardiyasi');
      // Gövde tam hedef durumu taşır; sunucudan mevcut değeri tersine
      // çevirmesi İSTENMEZ.
      expect(seenBody, {'status': 'completed', 'favorite': false});
    });

    test('upsertEntry slug\'ı YOLA kodlar', () async {
      final repository = build(_fixture('library-mutation-response.v1.json'));
      await seed();

      await repository.upsertEntry(
        slug: 'seri/slug',
        status: LibraryStatus.plan,
        favorite: true,
      );

      expect(seenPath, '/api/library/seri%2Fslug');
    });

    test('removeEntry -> DELETE, gövde göndermez', () async {
      final repository = build(_fixture('library-removal-response.v1.json'));
      await seed();

      final response = await repository.removeEntry('gece-vardiyasi');

      expect(seenMethod, 'DELETE');
      expect(seenPath, '/api/library/gece-vardiyasi');
      expect(seenBody, isNull);
      expect(response.removed, isTrue);
    });

    test('removeEntry IDEMPOTENT: `removed: false` hata DEĞİLDİR, başarıyla '
        'döner', () async {
      final repository = build(
        jsonEncode({'schemaVersion': kSchemaVersion, 'removed': false}),
      );
      await seed();

      final response = await repository.removeEntry('hic-eklenmemis');

      expect(response.removed, isFalse);
    });
  });

  group('HttpLibraryRepository — kimlik ve hatalar', () {
    test('saklı oturum YOKSA sunucuya HİÇ istek gitmez ve sahte başarı '
        'üretilmez (ADR-010)', () async {
      var requestCount = 0;
      tokenStore = InMemoryTokenStore();
      authRepository = _FakeAuthRepository(tokenStore: tokenStore);
      final client = PanelyaApiClient(
        apiOrigin: _apiOrigin,
        httpClient: MockClient((request) async {
          requestCount++;
          return _json(_fixture('library-response.v1.json'));
        }),
      );
      final repository = HttpLibraryRepository(
        client: client,
        tokenStore: tokenStore,
        authRepository: authRepository,
      );

      await expectLater(
        repository.fetchLibrary(),
        throwsA(isA<LibraryNotAuthenticatedException>()),
      );
      expect(requestCount, 0);
    });

    test('sunucunun yapılandırılmış hata gövdesi domain tipine çevrilir ve '
        'kendi açıklaması korunur', () async {
      final repository = build(
        _fixture('library-error.v1.json'),
        status: 401,
        refreshShouldFail: true,
      );
      await seed();

      await expectLater(
        repository.fetchLibrary(),
        throwsA(
          isA<LibraryServerException>()
              .having((e) => e.isNotAuthenticated, 'isNotAuthenticated', isTrue)
              .having(
                (e) => e.message,
                'message',
                'Bu işlem için giriş yapmalısın.',
              ),
        ),
      );
    });

    test('süresi dolmuş token BİR KEZ yenilenip istek tekrarlanır', () async {
      tokenStore = InMemoryTokenStore();
      authRepository = _FakeAuthRepository(tokenStore: tokenStore);
      final sentTokens = <String?>[];
      final client = PanelyaApiClient(
        apiOrigin: _apiOrigin,
        httpClient: MockClient((request) async {
          sentTokens.add(request.headers['Authorization']);
          return sentTokens.length == 1
              ? _json(_fixture('library-error.v1.json'), status: 401)
              : _json(_fixture('library-response.v1.json'));
        }),
      );
      final repository = HttpLibraryRepository(
        client: client,
        tokenStore: tokenStore,
        authRepository: authRepository,
      );
      await tokenStore.write(_tokens('eski-token'));

      final response = await repository.fetchLibrary();

      expect(response.items, hasLength(1));
      expect(authRepository.refreshCalls, 1);
      expect(sentTokens, ['Bearer eski-token', 'Bearer yenilenmis-token']);
    });

    test('ağ hatası LibraryUnexpectedException olur', () async {
      tokenStore = InMemoryTokenStore();
      authRepository = _FakeAuthRepository(tokenStore: tokenStore);
      final client = PanelyaApiClient(
        apiOrigin: _apiOrigin,
        httpClient: MockClient((request) async {
          throw const SocketException('baglanti yok');
        }),
      );
      final repository = HttpLibraryRepository(
        client: client,
        tokenStore: tokenStore,
        authRepository: authRepository,
      );
      await tokenStore.write(_tokens('token'));

      await expectLater(
        repository.fetchLibrary(),
        throwsA(isA<LibraryUnexpectedException>()),
      );
    });
  });

  group('HttpLibraryRepository — sıralama', () {
    test('sunucunun verdiği SIRA korunur; istemci updatedAt\'ten yeniden '
        'sıralama üretmez', () async {
      // Kasıtlı olarak `updatedAt` bakımından ARTAN sırada DEĞİL.
      final base =
          jsonDecode(_fixture('library-response.v1.json'))
              as Map<String, dynamic>;
      final item = base['items'][0] as Map<String, dynamic>;

      Map<String, dynamic> withSlug(String slug, String updatedAt) {
        final copy = jsonDecode(jsonEncode(item)) as Map<String, dynamic>;
        (copy['series'] as Map<String, dynamic>)['slug'] = slug;
        copy['updatedAt'] = updatedAt;
        return copy;
      }

      final repository = build(
        jsonEncode({
          'schemaVersion': kSchemaVersion,
          'items': [
            withSlug('en-eski', '2020-01-01T00:00:00.000Z'),
            withSlug('en-yeni', '2030-01-01T00:00:00.000Z'),
            withSlug('ortanca', '2025-01-01T00:00:00.000Z'),
          ],
        }),
      );
      await seed();

      final response = await repository.fetchLibrary();

      expect(
        response.items.map((i) => i.series.slug).toList(),
        ['en-eski', 'en-yeni', 'ortanca'],
        reason: 'sunucu sırası olduğu gibi korunmalı',
      );
    });
  });
}
