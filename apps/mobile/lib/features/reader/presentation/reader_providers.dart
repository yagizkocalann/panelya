import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/provider_retry_policy.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../offline/presentation/offline_providers.dart';
import '../data/api_reader_repository.dart';
import '../domain/reader_content.dart';
import '../domain/reader_repository.dart';

final readerRepositoryProvider = Provider<ReaderRepository>((ref) {
  return ApiReaderRepository(ref.watch(apiClientProvider));
});

/// Bölüm manifesti sorgu anahtarı: seri + bölüm slug'ı.
typedef EpisodeManifestKey = ({String seriesSlug, String episodeSlug});

/// `GET /api/series/:slug/episodes/:episodeSlug` sonucu. Otomatik yeniden
/// deneme kapalıdır (bkz. `core/api/provider_retry_policy.dart`).
///
/// `ReaderScreen` bu provider'ı DOĞRUDAN İZLEMEZ — bkz. aşağıdaki
/// [readerContentProvider]; bu, yalnız o provider'ın "çevrimiçi" dalı ve
/// bir bölümü ÖNCEDEN indirmeden önce manifestini almak isteyen gelecekteki
/// bir "seriyi indir" akışı (bkz. docs/local-gap-backlog.md P2 madde 3'ün
/// "sonra seri" adımı) için ayrı bir giriş noktası olarak var.
final episodeManifestProvider =
    FutureProvider.family<EpisodeManifestResponse, EpisodeManifestKey>(
      (ref, key) => ref
          .watch(readerRepositoryProvider)
          .fetchEpisodeManifest(key.seriesSlug, key.episodeSlug),
      retry: noAutomaticRetry,
    );

/// `ReaderScreen`'in gerçekte gösterdiği içerik: bölüm daha önce cihaza
/// indirilmişse (bkz. `features/offline/`) yerel diskten, değilse ağdan
/// gelir. Böylece indirilmiş bir bölüm uçak modunda / internetsiz de
/// açılabilir — offline repository'nin kendisi hiçbir ağ isteği yapmaz,
/// yalnız daha önce yazılmış dosyaları okur.
///
/// Otomatik yeniden deneme kapalıdır (bkz. [episodeManifestProvider] ile
/// aynı gerekçe).
final readerContentProvider =
    FutureProvider.family<ReaderContent, EpisodeManifestKey>((ref, key) async {
      final offlineContent = await ref
          .watch(offlineEpisodeRepositoryProvider)
          .loadDownloaded(key.seriesSlug, key.episodeSlug);
      if (offlineContent != null) {
        return ReaderContent.offline(
          offlineContent.manifest,
          offlineContent.panelImageFiles,
        );
      }

      final manifest = await ref
          .watch(readerRepositoryProvider)
          .fetchEpisodeManifest(key.seriesSlug, key.episodeSlug);
      return ReaderContent.online(manifest);
    }, retry: noAutomaticRetry);
