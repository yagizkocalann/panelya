import '../../../core/contracts/episode_manifest_response.dart';

/// Okuyucu manifesti verisine erişim sözleşmesi.
///
/// (bkz. docs/mobile-handoff.md Ortaklık kuralları #2.)
abstract class ReaderRepository {
  /// `GET /api/series/:slug/episodes/:episodeSlug`. Seri veya bölüm
  /// bulunamazsa `HttpStatusException(statusCode: 404)` fırlatır.
  Future<EpisodeManifestResponse> fetchEpisodeManifest(
    String seriesSlug,
    String episodeSlug,
  );
}
