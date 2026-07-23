import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:panelya_mobile/core/api/api_client.dart';
import 'package:panelya_mobile/core/api/api_exception.dart';
import 'package:panelya_mobile/features/discovery/data/api_discovery_repository.dart';
import 'package:panelya_mobile/features/discovery/domain/discovery_repository.dart';

/// `ApiDiscoveryRepository` + `PanelyaApiClient.fetchDiscovery` birim testi;
/// gerçek (SALT OKUNUR) `packages/contracts/fixtures/discovery.v1.json`
/// sentetik fixture'ını okur (bkz. `fixture_contracts_test.dart`'taki aynı
/// desen). Widget'lar bu iki katmana asla doğrudan dokunmaz — yalnız
/// `discoveryRepositoryProvider`/`discoveryProvider` üzerinden (bkz.
/// `discovery_providers.dart`); bu test o zincirin altındaki gerçek HTTP +
/// parse + repository davranışını doğrular.
const _fixturePath = '../../packages/contracts/fixtures/discovery.v1.json';

void main() {
  late String fixtureJson;

  setUpAll(() {
    fixtureJson = File(_fixturePath).readAsStringSync();
  });

  group('ApiDiscoveryRepository.fetchDiscovery', () {
    test('delegates to GET /api/discovery and returns the parsed DiscoveryResponse', () async {
      Uri? requestedUri;
      final mock = MockClient((request) async {
        requestedUri = request.url;
        // `content-type: application/json` başlığı açıkça verilir:
        // fixture Türkçe karakterler (ü, ş, ı, İ) taşır ve
        // `package:http`'nin `Response` gövde kodlayıcısı yalnız
        // `application/json` içerik tipi için UTF-8'e düşer; başlıksız
        // durumda varsayılan Latin-1'dir (bkz. `api_client_test.dart`
        // dosyasındaki eşdeğer not).
        return http.Response(
          fixtureJson,
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final client = PanelyaApiClient(
        apiOrigin: 'http://localhost:3000',
        httpClient: mock,
      );
      final DiscoveryRepository repository = ApiDiscoveryRepository(client);

      final response = await repository.fetchDiscovery();

      expect(requestedUri?.path, '/api/discovery');
      expect(response.schemaVersion, '1.0');
      expect(response.featuredSeries?.slug, 'gece-denemesi');
      expect(response.genres, ['Gizem', 'Romantik']);
      expect(response.newSeries, hasLength(1));
      expect(response.latestEpisodes, hasLength(1));
      expect(response.latestEpisodes.single.episode.title, 'İlk İşaret');
    });

    test('surfaces server errors as HttpStatusException', () async {
      final mock = MockClient((request) async => http.Response('', 503));
      final client = PanelyaApiClient(
        apiOrigin: 'http://localhost:3000',
        httpClient: mock,
      );
      final DiscoveryRepository repository = ApiDiscoveryRepository(client);

      await expectLater(
        repository.fetchDiscovery(),
        throwsA(isA<HttpStatusException>()),
      );
    });
  });
}
