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
}
