import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_error_presenter.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/config/app_config.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../../features/library/presentation/library_add_action.dart';
import '../../../features/offline/presentation/episode_download_button.dart';
import '../../../features/offline/presentation/offline_providers.dart';
import '../../../features/progress/domain/reading_progress.dart';
import '../../../features/progress/presentation/reading_progress_providers.dart';
import '../../../features/reader/presentation/reader_providers.dart';
import '../../../shared/layout/content_max_width.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../../shared/widgets/home_button.dart';
import '../../../shared/widgets/state_views.dart';
import 'series_providers.dart';

/// Seri detay ekranı (`/series/:slug`): `GET /api/series/:slug`'dan gelen
/// kapak, meta veri ve bölüm listesini gösterir (bkz. PLAN Görev 3 ve
/// production-bible.md §7).
class SeriesScreen extends ConsumerWidget {
  const SeriesScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(seriesDetailProvider(slug));

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.asData?.value.series.title ?? 'Seri'),
        actions: const [HomeButton()],
      ),
      body: SafeArea(
        child: detail.when(
          loading: () => const AppLoadingView(label: 'Seri yükleniyor'),
          error: (error, stackTrace) => AppErrorView(
            message: error is ApiException
                ? describeApiException(error)
                : 'Beklenmeyen bir hata oluştu.',
            onRetry: () => ref.invalidate(seriesDetailProvider(slug)),
          ),
          data: (response) =>
              _SeriesDetailView(seriesSlug: slug, response: response),
        ),
      ),
    );
  }
}

/// Bölümler arasında görünen numaraya (sequence etiketine) göre en küçük
/// olanı bulur. Sunucu bölümleri yeni-en eski sıralı döndürür (bkz.
/// `lib/core/contracts/generated/series_detail_response.dart`), ama
/// "Okumaya başla" ilk bölüme (en düşük numaraya) götürmelidir (bkz. PLAN
/// Görev 3); bu yüzden sıralamaya güvenmek yerine açıkça en küçük
/// `number`'ı arar.
EpisodeSummary firstEpisodeOf(List<EpisodeSummary> episodes) {
  return episodes.reduce((a, b) => a.number <= b.number ? a : b);
}

class _SeriesDetailView extends ConsumerWidget {
  const _SeriesDetailView({required this.seriesSlug, required this.response});

  final String seriesSlug;
  final SeriesDetailResponse response;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final metadata = response.series;
    final episodes = response.episodes;

    if (episodes.isEmpty) {
      return const AppEmptyView(
        message: 'Bu serinin henüz yayınlanmış bölümü yok.',
      );
    }

    final firstEpisode = firstEpisodeOf(episodes);
    // Cihaz-yerel "kaldığın yerden devam et" kaydı (bkz. PLAN, hesapsız
    // özellik — auth'lu `/api/progress` ile ilgisi yok). Kayıt yoksa
    // mevcut "Okumaya başla" davranışı değişmeden kalır.
    final progress = ref.watch(readingProgressForSeriesProvider(seriesSlug));

    // Geniş ekranlarda (tablet) içerik okuyucudakiyle tutarlı bir merkez
    // sütunda sınırlanır; kapak görseli tam ekran genişliğine (ve onunla
    // birlikte 3:4 oranla devasa bir yüksekliğe) büyümez (bkz. PLAN Görev
    // A.2). Telefon genişliklerinde etkisi yoktur.
    return CenteredMaxWidth(
      child: ListView(
        padding: EdgeInsets.all(tokens.spacing.md),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radii.lg),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: CoverImage(
                src: metadata.coverImage,
                position: metadata.coverPosition,
                semanticLabel: metadata.title,
                tone: metadata.tone,
                variants: metadata.coverImageVariants,
              ),
            ),
          ),
          SizedBox(height: tokens.spacing.md),
          Text(
            metadata.eyebrow,
            style: tokens.typography.bodySmall.copyWith(
              color: tokens.colors.mint,
            ),
          ),
          SizedBox(height: tokens.spacing.xs),
          Text(metadata.title, style: tokens.typography.displayLarge),
          SizedBox(height: tokens.spacing.xs),
          Semantics(
            label: 'Yaratıcı: ${metadata.creator}',
            child: Text(metadata.creator, style: tokens.typography.bodyMedium),
          ),
          SizedBox(height: tokens.spacing.sm),
          Semantics(
            label:
                '${metadata.rating.toStringAsFixed(1)} üzerinden puan, '
                '${metadata.followers} takipçi, ${episodes.length} bölüm.',
            child: Wrap(
              spacing: tokens.spacing.md,
              runSpacing: tokens.spacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // `mainAxisSize.min` bu Row'un yalnız gerektiği kadar yer
                // kaplamasını sağlar, ama büyük yazı tipinde (`textScaler`)
                // metin `Wrap`'ın verdiği sınırlı genişliği aşabilir; bu bir
                // `Flexible` olmadan RenderFlex taşmasına yol açıyordu (bkz.
                // PLAN Görev B.1/B.2 — metin KIRPILIR, bilgi tam
                // kaybolmaz).
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: tokens.colors.mint,
                    ),
                    SizedBox(width: tokens.spacing.xs / 2),
                    Flexible(
                      child: Text(
                        metadata.rating.toStringAsFixed(1),
                        style: tokens.typography.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_alt_outlined,
                      size: 16,
                      color: tokens.colors.muted,
                    ),
                    SizedBox(width: tokens.spacing.xs / 2),
                    Flexible(
                      child: Text(
                        '${metadata.followers} takipçi',
                        style: tokens.typography.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${episodes.length} bölüm',
                  style: tokens.typography.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.spacing.md),
          Wrap(
            spacing: tokens.spacing.xs,
            runSpacing: tokens.spacing.xs,
            children: [
              _Tag(text: metadata.status),
              for (final genre in metadata.genres) _Tag(text: genre),
            ],
          ),
          SizedBox(height: tokens.spacing.md),
          Text(metadata.longDescription, style: tokens.typography.bodyLarge),
          SizedBox(height: tokens.spacing.lg),
          _StartReadingActions(
            seriesSlug: seriesSlug,
            firstEpisode: firstEpisode,
            progress: progress,
          ),
          SizedBox(height: tokens.spacing.lg),
          // `Row` DEĞİL `Wrap`: büyük yazı tipinde (`textScaler`) "Tümünü
          // indir" etiketi "Bölümler" başlığıyla aynı satıra sığmayabilir
          // (bkz. PLAN Görev B.1 — bu diğer meta veri satırlarında da aynı
          // desen, örn. yukarıdaki puan/takipçi `Wrap`'ı); `Wrap` bu
          // durumda ikinci öğeyi bir alt satıra taşır, RenderFlex taşması
          // yerine.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: tokens.spacing.sm,
            runSpacing: tokens.spacing.xs,
            children: [
              Text('Bölümler', style: tokens.typography.titleMedium),
              _DownloadAllButton(seriesSlug: seriesSlug, episodes: episodes),
            ],
          ),
          SizedBox(height: tokens.spacing.sm),
          for (final episode in episodes)
            _EpisodeTile(
              seriesSlug: seriesSlug,
              episode: episode,
              onTap: () =>
                  context.push('/series/$seriesSlug/read/${episode.slug}'),
            ),
        ],
      ),
    );
  }
}

/// Seri detayının birincil okuma aksiyonu.
///
/// Cihaz-yerel ilerleme kaydı [progress] `null` ise (kullanıcı bu seride
/// hiç bölüm açmamış) mevcut tek "Okumaya başla" davranışı değişmeden
/// kalır. Kayıt varsa birincil aksiyon "Devam et: Bölüm N" olur ve
/// kaydedilen bölüme götürür; yanında daha küçük bir ikincil "Baştan
/// başla" aksiyonu her zaman ilk bölüme döner (PLAN — hesapsız, cihaz-yerel
/// "kaldığın yerden devam et").
class _StartReadingActions extends StatelessWidget {
  const _StartReadingActions({
    required this.seriesSlug,
    required this.firstEpisode,
    required this.progress,
  });

  final String seriesSlug;
  final EpisodeSummary firstEpisode;
  final ReadingProgress? progress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    if (progress == null) {
      // Sabit `SizedBox(height: minTouchTarget)` yerine YALNIZ tema
      // düzeyindeki `FilledButtonThemeData.minimumSize` (bkz. theme.dart)
      // 44 px alt sınırı sağlar; büyük yazı tipinde (`textScaler`) buton
      // gerektiğinde 44 px'in ÜZERİNE büyüyebilir — aksi halde etiket
      // kırpılır/taşardı (bkz. PLAN Görev B.2 — "buton etiketi kırpılmaz").
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: () =>
                context.push('/series/$seriesSlug/read/${firstEpisode.slug}'),
            child: Text('Okumaya başla · Bölüm ${firstEpisode.number}'),
          ),
          SizedBox(height: tokens.spacing.sm),
          LibraryAddAction(seriesSlug: seriesSlug),
        ],
      );
    }

    // `FilledButton`/`OutlinedButton` her biri kendi `button: true` +
    // metin-tabanlı semantics etiketini zaten üretir (bkz. codebase
    // genelindeki diğer butonlar — "Okumaya başla", "Seriyi incele" vb.);
    // ek bir dış `Semantics` sarmalayıcı gereksiz, iç içe iki düğüm
    // oluşturup ekran okuyucuda yinelemeye yol açardı. Bu iki aksiyon zaten
    // ayrı `SizedBox`/buton olduğundan ayrı ayrı erişilebilirler.
    final continueLabel = 'Devam et: Bölüm ${progress!.episodeNumber}';
    // Bkz. yukarıdaki not: sabit yükseklikli `SizedBox` yerine butonlar
    // tema `minimumSize`'ından (44 px alt sınır) büyüyebilir bırakılır.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: () =>
              context.push('/series/$seriesSlug/read/${progress!.episodeSlug}'),
          child: Text(continueLabel),
        ),
        SizedBox(height: tokens.spacing.sm),
        OutlinedButton(
          onPressed: () =>
              context.push('/series/$seriesSlug/read/${firstEpisode.slug}'),
          child: const Text('Baştan başla'),
        ),
        SizedBox(height: tokens.spacing.sm),
        LibraryAddAction(seriesSlug: seriesSlug),
      ],
    );
  }
}

/// "Bölümler" başlığının yanındaki toplu indirme aksiyonu
/// (docs/local-gap-backlog.md P2 madde 3'ün "önce bölüm, sonra seri"
/// planının ikinci adımı). Seride henüz indirilmemiş her bölümü SIRAYLA
/// indirir (aynı anda çoklu istek göndermek yerine — hem sunucuya nazik
/// hem de "N/M indirildi" ilerlemesini basit, tek bir sayaçla göstermeyi
/// sağlar). Bölümler zaten indirilmişse [EpisodeDownloadButton.downloadEpisode]
/// (dolaylı olarak `isDownloaded` kontrolü üzerinden) hiçbir ağ isteği
/// yapmadan anında atlanır.
///
/// Kasıtlı olarak "hepsi zaten indirilmişse gizlen" mantığı YOK: bunun
/// için her bölümün indirilmiş durumunu ayrı ayrı reaktif izlemek
/// gerekirdi; bunun yerine buton her zaman görünür kalır ve tekrar
/// dokunmak (indirilecek hiçbir şey kalmadıysa) zaten anında biter — basit
/// ve yeterli bir v1 davranışı.
class _DownloadAllButton extends ConsumerStatefulWidget {
  const _DownloadAllButton({required this.seriesSlug, required this.episodes});

  final String seriesSlug;
  final List<EpisodeSummary> episodes;

  @override
  ConsumerState<_DownloadAllButton> createState() => _DownloadAllButtonState();
}

class _DownloadAllButtonState extends ConsumerState<_DownloadAllButton> {
  bool _running = false;
  int _completed = 0;

  Future<void> _downloadAll() async {
    setState(() {
      _running = true;
      _completed = 0;
    });

    final offlineRepository = ref.read(offlineEpisodeRepositoryProvider);
    final readerRepository = ref.read(readerRepositoryProvider);
    final apiOrigin = ref.read(appConfigProvider).apiOrigin;
    var hadFailure = false;

    for (final episode in widget.episodes) {
      try {
        final alreadyDownloaded = await offlineRepository.isDownloaded(
          widget.seriesSlug,
          episode.slug,
        );
        if (!alreadyDownloaded) {
          final manifest = await readerRepository.fetchEpisodeManifest(
            widget.seriesSlug,
            episode.slug,
          );
          await offlineRepository
              .downloadEpisode(apiOrigin: apiOrigin, manifest: manifest)
              .drain<void>();
          ref.invalidate(
            isEpisodeDownloadedProvider((
              seriesSlug: widget.seriesSlug,
              episodeSlug: episode.slug,
            )),
          );
        }
      } catch (_) {
        // Bir bölüm başarısız olsa da geri kalanlar denenmeye devam eder
        // (bkz. sınıf doc yorumu — sıralı, birbirinden bağımsız indirmeler);
        // sonda tek bir özet uyarı gösterilir.
        hadFailure = true;
      }
      if (!mounted) return;
      setState(() => _completed++);
    }

    // "İndirilenler" ekranı (bkz. `downloads_screen.dart`) ayrı bir
    // provider'dan (`downloadedEpisodesProvider`) okur; yukarıdaki
    // döngüdeki tekil `isEpisodeDownloadedProvider` invalidate'i onu
    // TAZELEMEZ — bu toplu indirme bittiğinde bir kez açıkça yapılması
    // gerekir, yoksa o ekran zaten okunmuş eski (bu indirmeden önceki)
    // önbellek değerini göstermeye devam eder.
    ref.invalidate(downloadedEpisodesProvider);

    if (!mounted) return;
    setState(() => _running = false);
    if (hadFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bazı bölümler indirilemedi. Lütfen tekrar deneyin.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    if (_running) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: tokens.colors.mint,
            ),
          ),
          SizedBox(width: tokens.spacing.xs),
          Text(
            'İndiriliyor $_completed/${widget.episodes.length}',
            style: tokens.typography.bodySmall,
          ),
        ],
      );
    }

    return TextButton.icon(
      onPressed: _downloadAll,
      icon: const Icon(Icons.download_outlined, size: 18),
      label: const Text('Tümünü indir'),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.sm,
        vertical: tokens.spacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.surface3,
        borderRadius: BorderRadius.circular(tokens.radii.pill),
      ),
      child: Text(text, style: tokens.typography.bodySmall),
    );
  }
}

class _EpisodeTile extends ConsumerWidget {
  const _EpisodeTile({
    required this.seriesSlug,
    required this.episode,
    required this.onTap,
  });

  final String seriesSlug;
  final EpisodeSummary episode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    return Semantics(
      button: true,
      label:
          'Bölüm ${episode.number}: ${episode.title}. ${episode.publishedAt}. ${episode.readTime}.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radii.md),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: tokens.sizes.minTouchTarget),
          child: Container(
            margin: EdgeInsets.only(bottom: tokens.spacing.sm),
            padding: EdgeInsets.all(tokens.spacing.md),
            decoration: BoxDecoration(
              color: tokens.colors.surface2,
              borderRadius: BorderRadius.circular(tokens.radii.md),
              border: Border.all(color: tokens.colors.line),
            ),
            child: Row(
              children: [
                _SequenceBadge(number: episode.number, tokens: tokens),
                SizedBox(width: tokens.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episode.title,
                        style: tokens.typography.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: tokens.spacing.xs),
                      Text(
                        '${episode.publishedAt} · ${episode.readTime} · ${episode.panelCount} panel',
                        style: tokens.typography.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                EpisodeDownloadButton(
                  seriesSlug: seriesSlug,
                  episodeSlug: episode.slug,
                  resolveManifest: () => ref
                      .read(readerRepositoryProvider)
                      .fetchEpisodeManifest(seriesSlug, episode.slug),
                ),
                Icon(Icons.chevron_right, color: tokens.colors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bölümün görünür sıra etiketi ("Bölüm N"'in rozet biçimi).
class _SequenceBadge extends StatelessWidget {
  const _SequenceBadge({required this.number, required this.tokens});

  final int number;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    final size = tokens.spacing.xl + tokens.spacing.sm;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.colors.surface3,
        borderRadius: BorderRadius.circular(tokens.radii.md),
      ),
      // Sabit boyutlu (44x44'lük) bir kutu; büyük yazı tipinde numara
      // metni kutudan taşmasın diye `FittedBox` ile gerekirse küçültülür
      // (bkz. PLAN Görev B.2 — bilgi kaybı yok, yalnız görsel ölçek).
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$number',
          style: tokens.typography.titleMedium.copyWith(
            color: tokens.colors.mint,
          ),
        ),
      ),
    );
  }
}
