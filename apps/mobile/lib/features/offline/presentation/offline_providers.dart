import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/offline_storage_provider.dart';
import '../data/file_system_offline_episode_repository.dart';
import '../domain/downloaded_episode.dart';
import '../domain/offline_episode_repository.dart';

/// Aktif [OfflineEpisodeRepository]. Ekranlar `dart:io`'yu değil bu
/// provider'ı (veya aşağıdaki türetilmiş provider'ı) kullanır.
final offlineEpisodeRepositoryProvider = Provider<OfflineEpisodeRepository>((
  ref,
) {
  return FileSystemOfflineEpisodeRepository(
    ref.watch(offlineStorageDirectoryProvider),
  );
});

/// Bir bölümün indirilmiş/indirilmemiş sorgu anahtarı.
typedef OfflineEpisodeKey = ({String seriesSlug, String episodeSlug});

/// Bu bölüm cihaza indirilmiş mi (bkz. `_DownloadButton`,
/// `reader_screen.dart` — indirme/silme sonrası bu provider açıkça
/// `ref.invalidate` edilir, aksi halde eski değer önbellekte kalırdı).
final isEpisodeDownloadedProvider = FutureProvider.family<bool, OfflineEpisodeKey>(
  (ref, key) => ref
      .watch(offlineEpisodeRepositoryProvider)
      .isDownloaded(key.seriesSlug, key.episodeSlug),
);

/// Cihaza indirilmiş TÜM bölümler (bkz. "İndirilenler" ekranı,
/// `downloads_screen.dart`). İndirme/silme sonrası bu provider açıkça
/// `ref.invalidate` edilir (bkz. [EpisodeDownloadButton.onChanged]
/// kullanımı o ekranda).
final downloadedEpisodesProvider = FutureProvider<List<DownloadedEpisode>>((
  ref,
) {
  return ref.watch(offlineEpisodeRepositoryProvider).listDownloaded();
});
