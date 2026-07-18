import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/provider_retry_policy.dart';
import '../../../core/contracts/episode_manifest_response.dart';
import '../data/api_reader_repository.dart';
import '../domain/reader_repository.dart';

final readerRepositoryProvider = Provider<ReaderRepository>((ref) {
  return ApiReaderRepository(ref.watch(apiClientProvider));
});

/// Bölüm manifesti sorgu anahtarı: seri + bölüm slug'ı.
typedef EpisodeManifestKey = ({String seriesSlug, String episodeSlug});

/// `GET /api/series/:slug/episodes/:episodeSlug` sonucu. Otomatik yeniden
/// deneme kapalıdır (bkz. `core/api/provider_retry_policy.dart`).
final episodeManifestProvider =
    FutureProvider.family<EpisodeManifestResponse, EpisodeManifestKey>(
      (ref, key) => ref
          .watch(readerRepositoryProvider)
          .fetchEpisodeManifest(key.seriesSlug, key.episodeSlug),
      retry: noAutomaticRetry,
    );
