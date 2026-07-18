import '../../../core/api/api_client.dart';
import '../../../core/contracts/catalog_response.dart';
import '../domain/discover_repository.dart';

/// [DiscoverRepository]'nin merkezi [PanelyaApiClient] üzerinden çalışan tek
/// implementasyonu. Faz 1'de yerel/çevrimdışı bir sahte implementasyon yok;
/// API her zaman canlı çağrılır ve hatalar ekran katmanında ele alınır.
class ApiDiscoverRepository implements DiscoverRepository {
  const ApiDiscoverRepository(this._client);

  final PanelyaApiClient _client;

  @override
  Future<CatalogResponse> fetchCatalog() => _client.fetchCatalog();
}
