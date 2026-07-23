import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:panelya_mobile/core/api/api_client.dart';
import 'package:panelya_mobile/core/api/api_exception.dart';

const _validCatalogJson = '''
{
  "schemaVersion": "1.0",
  "featuredSlug": "gece-vardiyasi",
  "series": []
}
''';

// Not: `http.Response`'a burada özel bir `Content-Type`/encoding
// verilmediği için `package:http`'nin varsayılan Latin-1 kodlayıcısı
// kullanılır (bkz. `MockClient` altyapısı); bu yüzden bu sabit JSON,
// diğer testlerdeki (`_validCatalogJson`) desenle tutarlı şekilde
// yalnız ASCII karakter taşır — gerçek Türkçe metin ayrıştırması
// `fixture_contracts_test.dart`'ta UTF-8 dosyadan okunan
// `discovery.v1.json` ile ayrıca doğrulanır.
const _validDiscoveryJson = '''
{
  "schemaVersion": "1.0",
  "featuredSeries": {
    "slug": "gece-vardiyasi",
    "title": "Gece Vardiyasi",
    "eyebrow": "Ozgun Seri",
    "creator": "Panelya Originals",
    "description": "Description",
    "longDescription": "Long description",
    "status": "Devam Ediyor",
    "genres": ["Gizem"],
    "tone": "mint",
    "updatedAt": "Bugun",
    "rating": 4.5,
    "followers": "1 B",
    "isNew": true,
    "episodeCount": 1
  },
  "featuredFirstEpisode": {
    "slug": "bolum-1",
    "number": 1,
    "title": "Bolum 1",
    "publishedAt": "18 Temmuz 2026",
    "readTime": "5 dk",
    "panelCount": 3
  },
  "genres": ["Gizem", "Romantik"],
  "newSeries": [
    {
      "slug": "gece-vardiyasi",
      "title": "Gece Vardiyasi",
      "eyebrow": "Ozgun Seri",
      "creator": "Panelya Originals",
      "description": "Description",
      "longDescription": "Long description",
      "status": "Devam Ediyor",
      "genres": ["Gizem"],
      "tone": "mint",
      "updatedAt": "Bugun",
      "rating": 4.5,
      "followers": "1 B",
      "isNew": true,
      "episodeCount": 1
    }
  ],
  "latestEpisodes": [
    {
      "series": {
        "slug": "gece-vardiyasi",
        "title": "Gece Vardiyasi",
        "eyebrow": "Ozgun Seri",
        "creator": "Panelya Originals",
        "description": "Description",
        "longDescription": "Long description",
        "status": "Devam Ediyor",
        "genres": ["Gizem"],
        "tone": "mint",
        "updatedAt": "Bugun",
        "rating": 4.5,
        "followers": "1 B",
        "isNew": true,
        "episodeCount": 1
      },
      "episode": {
        "slug": "bolum-1",
        "number": 1,
        "title": "Bolum 1",
        "publishedAt": "18 Temmuz 2026",
        "readTime": "5 dk",
        "panelCount": 3
      }
    }
  ]
}
''';

void main() {
  group('PanelyaApiClient error taxonomy', () {
    test('maps a 404 with an error body to HttpStatusException', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'series_not_found'}),
          404,
        );
      });
      final client = PanelyaApiClient(
        apiOrigin: 'http://localhost:3000',
        httpClient: mock,
      );

      await expectLater(
        client.fetchSeriesDetail('missing'),
        throwsA(
          isA<HttpStatusException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.isNotFound, 'isNotFound', isTrue)
              .having((e) => e.errorCode, 'errorCode', 'series_not_found'),
        ),
      );
    });

    test('maps a 500 to a server HttpStatusException', () async {
      final mock = MockClient((request) async => http.Response('', 500));
      final client = PanelyaApiClient(
        apiOrigin: 'http://localhost:3000',
        httpClient: mock,
      );

      await expectLater(
        client.fetchCatalog(),
        throwsA(
          isA<HttpStatusException>().having(
            (e) => e.isServerError,
            'isServerError',
            isTrue,
          ),
        ),
      );
    });

    test('maps a socket error to NetworkException', () async {
      final mock = MockClient((request) {
        throw const SocketException('connection refused');
      });
      final client = PanelyaApiClient(
        apiOrigin: 'http://localhost:3000',
        httpClient: mock,
      );

      await expectLater(
        client.fetchCatalog(),
        throwsA(isA<NetworkException>()),
      );
    });

    test('maps invalid JSON body to ParseException', () async {
      final mock = MockClient((request) async => http.Response('not json', 200));
      final client = PanelyaApiClient(
        apiOrigin: 'http://localhost:3000',
        httpClient: mock,
      );

      await expectLater(
        client.fetchCatalog(),
        throwsA(isA<ParseException>()),
      );
    });

    test('maps a schemaVersion mismatch to SchemaMismatchException', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({'schemaVersion': '2.0', 'featuredSlug': null, 'series': []}),
          200,
        );
      });
      final client = PanelyaApiClient(
        apiOrigin: 'http://localhost:3000',
        httpClient: mock,
      );

      await expectLater(
        client.fetchCatalog(),
        throwsA(isA<SchemaMismatchException>()),
      );
    });

    test('returns a parsed CatalogResponse on success', () async {
      final mock = MockClient(
        (request) async => http.Response(_validCatalogJson, 200),
      );
      final client = PanelyaApiClient(
        apiOrigin: 'http://localhost:3000',
        httpClient: mock,
      );

      final response = await client.fetchCatalog();

      expect(response.featuredSlug, 'gece-vardiyasi');
      expect(response.series, isEmpty);
    });
  });

  group('PanelyaApiClient.fetchDiscovery (GET /api/discovery)', () {
    test('requests the discovery endpoint and returns a parsed DiscoveryResponse', () async {
      Uri? requestedUri;
      final mock = MockClient((request) async {
        requestedUri = request.url;
        return http.Response(_validDiscoveryJson, 200);
      });
      final client = PanelyaApiClient(
        apiOrigin: 'http://localhost:3000',
        httpClient: mock,
      );

      final response = await client.fetchDiscovery();

      expect(requestedUri?.path, '/api/discovery');
      expect(response.schemaVersion, '1.0');
      expect(response.featuredSeries?.slug, 'gece-vardiyasi');
      expect(response.genres, ['Gizem', 'Romantik']);
      expect(response.newSeries, hasLength(1));
      expect(response.latestEpisodes, hasLength(1));
    });

    test('maps a 500 to a server HttpStatusException', () async {
      final mock = MockClient((request) async => http.Response('', 500));
      final client = PanelyaApiClient(
        apiOrigin: 'http://localhost:3000',
        httpClient: mock,
      );

      await expectLater(
        client.fetchDiscovery(),
        throwsA(
          isA<HttpStatusException>().having(
            (e) => e.isServerError,
            'isServerError',
            isTrue,
          ),
        ),
      );
    });

    test('maps a schemaVersion mismatch to SchemaMismatchException', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'schemaVersion': '2.0',
            'featuredSeries': null,
            'featuredFirstEpisode': null,
            'genres': <String>[],
            'newSeries': <dynamic>[],
            'latestEpisodes': <dynamic>[],
          }),
          200,
        );
      });
      final client = PanelyaApiClient(
        apiOrigin: 'http://localhost:3000',
        httpClient: mock,
      );

      await expectLater(
        client.fetchDiscovery(),
        throwsA(isA<SchemaMismatchException>()),
      );
    });

    test('maps a socket error to NetworkException', () async {
      final mock = MockClient((request) {
        throw const SocketException('connection refused');
      });
      final client = PanelyaApiClient(
        apiOrigin: 'http://localhost:3000',
        httpClient: mock,
      );

      await expectLater(
        client.fetchDiscovery(),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
