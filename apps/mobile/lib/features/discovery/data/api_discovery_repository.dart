import '../../../core/api/api_client.dart';
import '../../../core/contracts/generated/generated.dart';
import '../domain/discovery_repository.dart';

/// [DiscoveryRepository]'nin merkezi [PanelyaApiClient] üzerinden çalışan tek
/// implementasyonu. Yerel/çevrimdışı bir sahte implementasyon yok; API her
/// zaman canlı çağrılır ve hatalar ekran katmanında ele alınır.
class ApiDiscoveryRepository implements DiscoveryRepository {
  const ApiDiscoveryRepository(this._client);

  final PanelyaApiClient _client;

  @override
  Future<DiscoveryResponse> fetchDiscovery() => _client.fetchDiscovery();
}
