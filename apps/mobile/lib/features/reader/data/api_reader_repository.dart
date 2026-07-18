import '../../../core/api/api_client.dart';
import '../../../core/contracts/episode_manifest_response.dart';
import '../domain/reader_repository.dart';

class ApiReaderRepository implements ReaderRepository {
  const ApiReaderRepository(this._client);

  final PanelyaApiClient _client;

  @override
  Future<EpisodeManifestResponse> fetchEpisodeManifest(
    String seriesSlug,
    String episodeSlug,
  ) =>
      _client.fetchEpisodeManifest(seriesSlug, episodeSlug);
}
