import '../../../core/contracts/generated/generated.dart';

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
