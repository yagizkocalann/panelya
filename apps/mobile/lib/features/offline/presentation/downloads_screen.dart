import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../shared/utils/byte_size.dart';
import '../../../shared/widgets/home_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../../reader/presentation/reader_providers.dart';
import '../domain/downloaded_episode.dart';
import 'episode_download_button.dart';
import 'offline_providers.dart';

/// "İndirilenler" ekranı (`/downloads`): cihaza indirilmiş TÜM bölümleri
/// (tüm seriler dahil) tek bir listede gösterir (bkz.
/// docs/local-gap-backlog.md P2 madde 3 — "önce bölüm, sonra seri"
/// planının tamamlayıcısı). Seri/bölüm bazında indirme zaten seri
/// ekranından (bkz. `series_screen.dart`) ve okuyucudan (bkz.
/// `reader_screen.dart`) yapılabiliyordu; bu ekran onların YÖNETİM
/// yüzeyidir — ne indirilmiş, ne kadar yer kaplıyor ve tek tek/toplu
/// silme.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadedEpisodesProvider);
    final loadedEpisodes = downloads.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('İndirilenler'),
        actions: [
          // ADR-010: gerçekten silinecek bir şey yoksa aksiyon hiç
          // render edilmez (görünür ama işlevsiz buton yok).
          if (loadedEpisodes != null && loadedEpisodes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Tüm indirmeleri sil',
              onPressed: () =>
                  _confirmDeleteAll(context, ref, loadedEpisodes),
            ),
          const HomeButton(),
        ],
      ),
      body: SafeArea(
        child: downloads.when(
          loading: () => const AppLoadingView(label: 'İndirilenler yükleniyor'),
          error: (error, stackTrace) => AppErrorView(
            message: 'Beklenmeyen bir hata oluştu.',
            onRetry: () => ref.invalidate(downloadedEpisodesProvider),
          ),
          data: (episodes) => episodes.isEmpty
              ? const AppEmptyView(
                  message: 'Henüz indirilmiş bir bölüm yok.',
                )
              : _DownloadsList(episodes: episodes),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAll(
    BuildContext context,
    WidgetRef ref,
    List<DownloadedEpisode> episodes,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tüm indirmeleri sil'),
        content: Text(
          '${episodes.length} indirilmiş bölümün tamamı cihazdan silinsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Tümünü sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final repository = ref.read(offlineEpisodeRepositoryProvider);
    // Tek bir bölümün silinmesi başarısız olursa (ör. dosya sistemi hatası)
    // DÖNGÜ DURMAZ: geri kalanları silmeye devam ederiz, sonra kaç tanesinin
    // silinemediğini dürüstçe bildiririz. Eskiden ilk hata döngüyü kesiyor,
    // kısmi silme hiçbir mesaj olmadan "hiçbir şey olmamış" gibi
    // görünüyordu (ADR-010).
    var failed = 0;
    for (final episode in episodes) {
      try {
        await repository.deleteDownload(
          episode.seriesSlug,
          episode.episodeSlug,
        );
      } on Object {
        failed++;
        continue;
      }
      // Seri/okuyucu ekranındaki indirme düğmesi (bkz. `EpisodeDownloadButton`)
      // AYRI bir provider'dan (`isEpisodeDownloadedProvider`) okur; bu toplu
      // silme yolu `EpisodeDownloadButton._confirmDelete`'i (tek tek silmede
      // kullanılan, bu invalidate'i zaten yapan yol) atladığı için burada da
      // açıkça yapılmazsa o ekranlar dosyalar silinmiş olsa bile eski
      // "indirilmiş" durumunu göstermeye devam eder.
      ref.invalidate(
        isEpisodeDownloadedProvider((
          seriesSlug: episode.seriesSlug,
          episodeSlug: episode.episodeSlug,
        )),
      );
    }
    ref.invalidate(downloadedEpisodesProvider);

    if (failed > 0 && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$failed bölüm silinemedi. Tekrar dene.')),
      );
    }
  }
}

class _DownloadsList extends StatelessWidget {
  const _DownloadsList({required this.episodes});

  final List<DownloadedEpisode> episodes;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final totalBytes = episodes.fold<int>(0, (sum, e) => sum + e.sizeBytes);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.md,
            tokens.spacing.md,
            tokens.spacing.md,
            0,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${episodes.length} bölüm · ${formatByteSize(totalBytes)}',
              style: tokens.typography.bodySmall.copyWith(
                color: tokens.colors.muted,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.all(tokens.spacing.md),
            itemCount: episodes.length,
            separatorBuilder: (context, index) =>
                SizedBox(height: tokens.spacing.sm),
            itemBuilder: (context, index) =>
                _DownloadedEpisodeTile(episode: episodes[index]),
          ),
        ),
      ],
    );
  }
}

class _DownloadedEpisodeTile extends ConsumerWidget {
  const _DownloadedEpisodeTile({required this.episode});

  final DownloadedEpisode episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;

    return Semantics(
      button: true,
      label:
          '${episode.seriesTitle}, Bölüm ${episode.episodeNumber}: '
          '${episode.episodeTitle}. ${formatByteSize(episode.sizeBytes)}.',
      child: InkWell(
        onTap: () => context.push(
          '/series/${episode.seriesSlug}/read/${episode.episodeSlug}',
        ),
        borderRadius: BorderRadius.circular(tokens.radii.md),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: tokens.sizes.minTouchTarget),
          child: Container(
            padding: EdgeInsets.all(tokens.spacing.md),
            decoration: BoxDecoration(
              color: tokens.colors.surface2,
              borderRadius: BorderRadius.circular(tokens.radii.md),
              border: Border.all(color: tokens.colors.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episode.seriesTitle,
                        style: tokens.typography.bodySmall.copyWith(
                          color: tokens.colors.mint,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: tokens.spacing.xs / 2),
                      Text(
                        'Bölüm ${episode.episodeNumber}: ${episode.episodeTitle}',
                        style: tokens.typography.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: tokens.spacing.xs),
                      Text(
                        formatByteSize(episode.sizeBytes),
                        style: tokens.typography.bodySmall.copyWith(
                          color: tokens.colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                EpisodeDownloadButton(
                  seriesSlug: episode.seriesSlug,
                  episodeSlug: episode.episodeSlug,
                  // Bu satırlar zaten indirilmiş bölümleri listeler, bu
                  // yüzden bu callback pratikte hiç çağrılmaz (buton hep
                  // "indirildi" durumunda başlar, yalnız silme onayına
                  // götürür) — yine de arayüz gerektirdiği için seri
                  // ekranındakiyle (bkz. `series_screen.dart`) AYNI
                  // gerçek kaynağa bağlanır.
                  resolveManifest: () => ref
                      .read(readerRepositoryProvider)
                      .fetchEpisodeManifest(
                        episode.seriesSlug,
                        episode.episodeSlug,
                      ),
                  onChanged: () => ref.invalidate(downloadedEpisodesProvider),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
