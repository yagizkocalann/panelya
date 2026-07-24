import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/config/app_config.dart';
import '../../../core/contracts/generated/generated.dart';
import 'offline_providers.dart';

/// Bir bölümü indirme/silme kontrolü (bkz. docs/local-gap-backlog.md P2
/// madde 3 — "Deep link, çevrimdışı okuma ve push bildirimleri"). Hem
/// okuyucu app bar'ında (bkz. `reader_screen.dart`) hem de seri ekranındaki
/// her bölüm satırında (bkz. `series_screen.dart`) kullanılan PAYLAŞILAN
/// widget — ikinci kullanım yeri ortaya çıkınca (seri ekranı, "önce bölüm
/// sonra seri" planının ikinci adımı) tek bir yere çıkarıldı.
///
/// [resolveManifest], indirme başlarken TAM manifesti (panel görselleri
/// dahil) döner. Okuyucu ekranı zaten elinde bir manifest olduğu için bunu
/// senkron biçimde sarar (`() => Future.value(manifest)`); seri ekranı
/// yalnız `EpisodeSummary` (özet) taşıdığı için bu callback'te
/// `ReaderRepository.fetchEpisodeManifest` çağrılır — bu widget'ın kendisi
/// `reader` özelliğine bağımlı DEĞİLDİR, çağıran taraf hangi kaynaktan
/// geleceğine karar verir.
///
/// Üç görsel durumu vardır: henüz indirilmemiş (indirme ikonu), indiriliyor
/// (yüzde ilerlemesi, dokunulamaz) ve indirilmiş (onay ikonu — dokununca
/// silme onayı ister). İndirme ilerlemesi bu widget'ın KENDİ (Riverpod
/// değil) yerel state'idir — ekrana/satıra özgü, geçici bir UI durumu.
class EpisodeDownloadButton extends ConsumerStatefulWidget {
  const EpisodeDownloadButton({
    super.key,
    required this.seriesSlug,
    required this.episodeSlug,
    required this.resolveManifest,
    this.onChanged,
  });

  final String seriesSlug;
  final String episodeSlug;
  final Future<EpisodeManifestResponse> Function() resolveManifest;

  /// İndirme veya silme başarıyla tamamlandığında çağrılır (bkz.
  /// `reader_screen.dart` — okuyucu bu geri çağrıyı kendi
  /// `readerContentProvider`'ını da tazelemek için kullanır).
  final VoidCallback? onChanged;

  @override
  ConsumerState<EpisodeDownloadButton> createState() =>
      _EpisodeDownloadButtonState();
}

class _EpisodeDownloadButtonState extends ConsumerState<EpisodeDownloadButton> {
  /// `null` iken indirme sürmüyor demektir; doluyken 0.0-1.0 arası ilerleme.
  double? _downloadProgress;

  OfflineEpisodeKey get _key =>
      (seriesSlug: widget.seriesSlug, episodeSlug: widget.episodeSlug);

  Future<void> _startDownload() async {
    setState(() => _downloadProgress = 0);
    try {
      final manifest = await widget.resolveManifest();
      final apiOrigin = ref.read(appConfigProvider).apiOrigin;
      final repository = ref.read(offlineEpisodeRepositoryProvider);
      await for (final progress in repository.downloadEpisode(
        apiOrigin: apiOrigin,
        manifest: manifest,
      )) {
        if (!mounted) return;
        setState(() => _downloadProgress = progress);
      }
      if (!mounted) return;
      setState(() => _downloadProgress = null);
      ref.invalidate(isEpisodeDownloadedProvider(_key));
      widget.onChanged?.call();
    } catch (_) {
      if (!mounted) return;
      setState(() => _downloadProgress = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bölüm indirilemedi. Lütfen tekrar deneyin.'),
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('İndirmeyi kaldır'),
        content: const Text(
          'Bu bölümün cihazdaki indirilmiş kopyası silinsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref
        .read(offlineEpisodeRepositoryProvider)
        .deleteDownload(widget.seriesSlug, widget.episodeSlug);
    ref.invalidate(isEpisodeDownloadedProvider(_key));
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final progress = _downloadProgress;

    if (progress != null) {
      return IconButton(
        icon: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            value: progress == 0 ? null : progress,
            strokeWidth: 2,
            color: tokens.colors.mint,
          ),
        ),
        tooltip: 'İndiriliyor · %${(progress * 100).round()}',
        onPressed: null,
      );
    }

    final downloaded = ref.watch(isEpisodeDownloadedProvider(_key));
    return downloaded.when(
      // Kontrol denetimi kısa sürer (yalnız yerel bir dosya var mı bakar);
      // bu ara durumda sabit boyutlu boş bir alan, ikonun aniden belirip
      // düzeni kaydırmasını önler.
      loading: () => const SizedBox(width: 48, height: 48),
      error: (error, stackTrace) => IconButton(
        icon: const Icon(Icons.download_outlined),
        tooltip: 'Bölümü indir',
        onPressed: _startDownload,
      ),
      data: (isDownloaded) => isDownloaded
          ? IconButton(
              icon: Icon(
                Icons.download_done_rounded,
                color: tokens.colors.mint,
              ),
              tooltip: 'İndirildi · kaldırmak için dokunun',
              onPressed: _confirmDelete,
            )
          : IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Bölümü indir',
              onPressed: _startDownload,
            ),
    );
  }
}
