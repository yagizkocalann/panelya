import '../../../core/api/api_client.dart';
import '../../../core/contracts/generated/generated.dart';
import '../domain/series_repository.dart';

class ApiSeriesRepository implements SeriesRepository {
  const ApiSeriesRepository(this._client);

  final PanelyaApiClient _client;

  @override
  Future<SeriesDetailResponse> fetchSeriesDetail(String slug) =>
      _client.fetchSeriesDetail(slug);
}
