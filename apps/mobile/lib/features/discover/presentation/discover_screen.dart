import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_error_presenter.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../../features/discovery/presentation/discovery_providers.dart';
import '../../../features/discovery/presentation/genre_disclosure.dart';
import '../../../features/progress/domain/reading_progress.dart';
import '../../../features/progress/presentation/reading_progress_providers.dart';
import '../../../shared/layout/content_max_width.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../../shared/widgets/episode_update_card.dart';
import '../../../shared/widgets/series_card.dart';
import '../../../shared/widgets/state_views.dart';

/// Keşif ızgarasının (ana sayfadaki "Yeni Seriler" önizlemesi ve `/catalog`,
/// `/new-series` ekranları) kolon sayısını genişliğe göre hesaplar (bkz. PLAN
/// Görev A.1): 360-430 telefon genişliğinde mevcut 2 kolon korunur;
/// ~768dp tablet dikeyde 3, ~900dp'de 4, ~1024dp tablet yatayda (ve
/// üzerinde) 5 kolona çıkar. Kart posterinin 3:4 oranı burada değil,
/// [seriesCardMainAxisExtent] ile hücre YÜKSEKLİĞİ üzerinden korunur; bu
/// fonksiyon yalnız kolon SAYISINI belirler.
int discoverGridColumnsForWidth(double width) {
  if (width >= 1024) return 5;
  if (width >= 900) return 4;
  if (width >= 600) return 3;
  return 2;
}

/// Bir seri kartı hücresinin gerekli toplam yüksekliği: 3:4 poster (kolon
/// genişliğinden türetilir, bkz. `SeriesCard`'taki `AspectRatio(3/4)`) +
/// altındaki metin bloğu (tür etiketi + başlık [en fazla 2 satır] + durum/
/// puan satırı).
///
/// `SliverGridDelegateWithFixedCrossAxisCount.childAspectRatio` SABİT bir
/// oran uygular; büyük yazı tipinde (`textScaler`) metin satırları
/// büyüdüğünde bu sabit oran hücreyi taşırırdı (RenderFlex overflow, bkz.
/// PLAN Görev B.1). Onun yerine burada `mainAxisExtent`, metin bloğunun
/// [MediaQuery.textScalerOf] ile ölçeklenen gerçek satır yüksekliklerinden
/// hesaplanır — hücre her zaman içeriğe yetecek kadar (ve fazlasıyla emniyet
/// payıyla) yüksek olur.
double seriesCardMainAxisExtent(BuildContext context, double columnWidth) {
  final tokens = context.tokens;
  final textScaler = MediaQuery.textScalerOf(context);

  double lineHeight(TextStyle style, {int lines = 1}) {
    final fontSize = style.fontSize ?? 14;
    final heightFactor = style.height ?? 1.2;
    return textScaler.scale(fontSize) * heightFactor * lines;
  }

  // Poster (3:4 — height = width * 4/3).
  final posterHeight = columnWidth * 4 / 3;

  // Metin bloğu: `SeriesCard`'taki tam sırayla (bkz. o dosyadaki yorum) —
  // tür etiketi HER ZAMAN bütçeye dahil edilir (yoksa boşluk artar, taşma
  // olmaz); başlık en fazla 2 satır.
  final textBlockHeight =
      tokens.spacing.sm +
      lineHeight(tokens.typography.bodySmall) +
      tokens.spacing.xs +
      lineHeight(tokens.typography.titleMedium, lines: 2) +
      tokens.spacing.xs +
      lineHeight(tokens.typography.bodySmall);

  // Küçük bir emniyet payı (yazı tipi metrikleri satır yüksekliği
  // çarpanından biraz farklı render edebilir).
  const safetyMargin = 4.0;

  return posterHeight + textBlockHeight + safetyMargin;
}

/// Editorial keşif ana sayfası (`/`, bkz. PLAN Görev 3 ve
/// docs/mobile-handoff.md "Güncel web bilgi mimarisinin Flutter karşılığı").
///
/// Sıra TAM OLARAK: 1) açılır tür dizini, 2) haftanın hikâyesi (hero),
/// 3) cihaz-yerel "Okumaya devam et" (yalnız kayıt varsa), 4) Yeni Seriler
/// (en fazla 4 kart + Tümünü Gör -> `/new-series`), 5) Yeni Eklenen
/// Bölümler (en fazla 4 kart + Tümünü Gör -> `/new-episodes`). Tüm veri tek
/// bir `GET /api/discovery` cevabından (bkz. `discoveryProvider`) gelir; tam
/// katalog (`GET /api/catalog`) artık yalnız `/catalog` ekranında kullanılır.
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discovery = ref.watch(discoveryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Panelya')),
      body: SafeArea(
        child: discovery.when(
          loading: () => const AppLoadingView(label: 'Keşif yükleniyor'),
          error: (error, stackTrace) => AppErrorView(
            message: error is ApiException
                ? describeApiException(error)
                : 'Beklenmeyen bir hata oluştu.',
            onRetry: () => ref.invalidate(discoveryProvider),
          ),
          data: (response) {
            final isEmpty =
                response.featuredSeries == null &&
                response.genres.isEmpty &&
                response.newSeries.isEmpty &&
                response.latestEpisodes.isEmpty;
            if (isEmpty) {
              return RefreshIndicator(
                onRefresh: () => ref.refresh(discoveryProvider.future),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: const [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: AppEmptyView(
                        message: 'Henüz yayınlanmış bir seri yok.',
                      ),
                    ),
                  ],
                ),
              );
            }
            return _DiscoverContent(response: response);
          },
        ),
      ),
    );
  }
}

class _DiscoverContent extends ConsumerWidget {
  const _DiscoverContent({required this.response});

  final DiscoveryResponse response;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    // Cihaz-yerel "kaldığın yerden devam et" kaydı (bkz. PLAN, hesapsız
    // özellik). Kayıt yoksa şerit hiç render edilmez — boş durum/placeholder
    // yok (ADR-010).
    final continueReading = ref.watch(mostRecentReadingProgressProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(discoveryProvider.future),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // 1) Açılır tür dizini — sayfanın en üstünde (bkz. PLAN Görev 4).
          SliverToBoxAdapter(
            child: GenreDisclosure(genres: response.genres),
          ),
          // 2) Haftanın hikâyesi.
          if (response.featuredSeries != null)
            SliverToBoxAdapter(
              child: CenteredMaxWidth(
                child: _FeaturedHero(
                  key: const ValueKey('featured-hero'),
                  series: response.featuredSeries!,
                  firstEpisode: response.featuredFirstEpisode,
                ),
              ),
            ),
          // 3) Cihaz-yerel "Okumaya devam et" — hero'nun altında, sonraki
          // bölümlerden önce (bkz. PLAN "keşif" maddesi).
          if (continueReading != null)
            SliverToBoxAdapter(
              child: CenteredMaxWidth(
                child: _ContinueReadingStrip(
                  key: const ValueKey('continue-reading-strip'),
                  progress: continueReading,
                ),
              ),
            ),
          // 4) Yeni Seriler — en fazla 4 kart + Tümünü Gör.
          if (response.newSeries.isNotEmpty)
            SliverToBoxAdapter(
              child: CenteredMaxWidth(
                child: _NewSeriesSection(series: response.newSeries),
              ),
            ),
          // 5) Yeni Eklenen Bölümler — en fazla 4 kart + Tümünü Gör.
          if (response.latestEpisodes.isNotEmpty)
            SliverToBoxAdapter(
              child: CenteredMaxWidth(
                child: _LatestEpisodesSection(updates: response.latestEpisodes),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: tokens.spacing.lg)),
        ],
      ),
    );
  }
}

/// Bir bölüm başlığı + "Tümünü Gör" bağlantısı (bkz. web `section-heading`
/// + `inline-link`, `app/page.tsx`).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onSeeAll,
    required this.seeAllKey,
  });

  final String title;
  final VoidCallback onSeeAll;

  /// Yalnız tıklanabilir "Tümünü Gör" hedefine iğnelenir — dış widget'ın
  /// (başlık metnini de kapsayan) tüm satırına DEĞİL, çünkü
  /// `tester.tap(find.byKey(...))` bir widget'ın merkezine dokunur; anahtar
  /// satırın tamamındaysa bu merkez başlık metnine denk gelip aksiyonu hiç
  /// tetiklemeyebilir.
  final Key seeAllKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.md,
        tokens.spacing.lg,
        tokens.spacing.md,
        tokens.spacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: tokens.typography.titleLarge),
          ),
          Semantics(
            button: true,
            label: '$title, tümünü gör',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: seeAllKey,
                onTap: onSeeAll,
                borderRadius: BorderRadius.circular(tokens.radii.md),
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: tokens.sizes.minTouchTarget,
                  ),
                  padding: EdgeInsets.symmetric(horizontal: tokens.spacing.sm),
                  alignment: Alignment.center,
                  child: Text(
                    'Tümünü Gör',
                    style: tokens.typography.label.copyWith(
                      color: tokens.colors.mint,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ana sayfadaki "Yeni Seriler" önizlemesi: `discoveryResponse.newSeries`'ten
/// EN FAZLA 4 kart (bkz. docs/mobile-handoff.md madde 4), API sırası
/// korunur. Tam liste `/new-series` ekranındadır (bkz.
/// `features/discovery/presentation/new_series_screen.dart`).
class _NewSeriesSection extends StatelessWidget {
  const _NewSeriesSection({required this.series});

  final List<DiscoverySeriesSummary> series;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final preview = series.take(4).toList(growable: false);

    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width < kContentMaxWidth ? width : kContentMaxWidth;
    final columns = discoverGridColumnsForWidth(maxWidth);
    final gridContentWidth = maxWidth - tokens.spacing.md * 2;
    final columnWidth =
        (gridContentWidth - (columns - 1) * tokens.spacing.md) / columns;
    final mainAxisExtent = seriesCardMainAxisExtent(context, columnWidth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          seeAllKey: const ValueKey('see-all-new-series'),
          title: 'Yeni Seriler',
          onSeeAll: () => context.push('/new-series'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.md),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: tokens.spacing.md,
              crossAxisSpacing: tokens.spacing.md,
              mainAxisExtent: mainAxisExtent,
            ),
            itemCount: preview.length,
            itemBuilder: (context, index) {
              final item = preview[index];
              return SeriesCard(
                key: ValueKey('series-card-${item.slug}'),
                series: SeriesCardData.fromDiscoverySeriesSummary(item),
                onTap: () => context.push('/series/${item.slug}'),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Ana sayfadaki "Yeni Eklenen Bölümler" önizlemesi:
/// `discoveryResponse.latestEpisodes`'ten EN FAZLA 4 kart, API sırası
/// korunur. Tam liste `/new-episodes` ekranındadır (bkz.
/// `features/discovery/presentation/new_episodes_screen.dart`).
class _LatestEpisodesSection extends StatelessWidget {
  const _LatestEpisodesSection({required this.updates});

  final List<DiscoveryEpisodeUpdate> updates;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final preview = updates.take(4).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          seeAllKey: const ValueKey('see-all-new-episodes'),
          title: 'Yeni Eklenen Bölümler',
          onSeeAll: () => context.push('/new-episodes'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.md),
          child: Column(
            children: [
              for (final update in preview) ...[
                EpisodeUpdateCard(
                  key: ValueKey(
                    'episode-update-${update.series.slug}-${update.episode.slug}',
                  ),
                  series: update.series,
                  episode: update.episode,
                  onOpenEpisode: () => context.push(
                    '/series/${update.series.slug}/read/${update.episode.slug}',
                  ),
                  onOpenSeries: () =>
                      context.push('/series/${update.series.slug}'),
                ),
                if (update != preview.last) SizedBox(height: tokens.spacing.sm),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Öne çıkan seri hero alanı (`featuredSeries`/`featuredFirstEpisode`).
/// [firstEpisode] `null` ise (seri var ama henüz yayınlanmış bölümü yok)
/// yalnız "Seriyi incele" aksiyonu gösterilir — "İlk bölümü oku" aksiyonu
/// hiç render edilmez, devre dışı/çalışmayan bir buton olarak DEĞİL (bkz.
/// ADR-010, docs/mobile-handoff.md madde 3).
///
/// Hero'nun kapaksız (placeholder) durumunda, ortadaki dekoratif kitap
/// ikonunun (`Icons.auto_stories_outlined`) gösterilmeye devam edebileceği en
/// büyük metin ölçeği. Bunun üzerinde (QA'da gözlenen 1.6+) durum/tür
/// chip'leri ikinci satıra sarar ve alttaki içerik bloğu yükselerek kartın
/// ortasına ulaşır; ikon SALT DEKORATİF olduğundan (bkz. `CoverImage`'daki
/// `Semantics` kapsamı dışı kalması) çakışacağı durumda gizlenmesi, üst üste
/// binmesinden daha doğrudur.
const double _heroDecorativeIconMaxTextScale = 1.5;

class _FeaturedHero extends StatelessWidget {
  const _FeaturedHero({
    super.key,
    required this.series,
    required this.firstEpisode,
  });

  final DiscoverySeriesSummary series;
  final EpisodeSummary? firstEpisode;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    // `TextScaler.scale(1.0)` katsayıyı (lineer ölçekleyicilerde) doğrudan
    // verir; `seriesCardMainAxisExtent`'teki satır yüksekliği hesaplamasıyla
    // aynı `MediaQuery.textScalerOf` kaynağını kullanır.
    final textScaleFactor = MediaQuery.textScalerOf(context).scale(1.0);
    final showDecorativeIcon =
        textScaleFactor <= _heroDecorativeIconMaxTextScale;
    final episode = firstEpisode;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.md,
        tokens.spacing.md,
        tokens.spacing.md,
        0,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radii.lg),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CoverImage(
                src: series.coverImage,
                position: series.coverPosition,
                semanticLabel: series.title,
                tone: series.tone,
                showDecorativeIcon: showDecorativeIcon,
                variants: series.coverImageVariants,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.3, 1],
                    colors: [
                      Colors.transparent,
                      tokens.colors.background.withValues(alpha: 0.94),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: tokens.spacing.md,
                right: tokens.spacing.md,
                bottom: tokens.spacing.md,
                child: Semantics(
                  label: 'Öne çıkan seri: ${series.title}. ${series.eyebrow}.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: tokens.spacing.xs,
                        runSpacing: tokens.spacing.xs,
                        children: [
                          _Pill(
                            text: 'Haftanın hikâyesi',
                            tokens: tokens,
                            highlight: true,
                          ),
                          _Pill(text: series.status, tokens: tokens),
                          _Pill(
                            text: '${series.episodeCount} bölüm',
                            tokens: tokens,
                          ),
                        ],
                      ),
                      SizedBox(height: tokens.spacing.sm),
                      Text(
                        series.title,
                        style: tokens.typography.displayLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: tokens.spacing.xs),
                      Text(
                        series.description,
                        style: tokens.typography.bodyMedium.copyWith(
                          color: tokens.colors.ink,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: tokens.spacing.md),
                      // Sabit `SizedBox(height: minTouchTarget)` yerine
                      // tema `FilledButtonThemeData.minimumSize` (44 px alt
                      // sınır) uygulanır; büyük yazı tipinde buton
                      // gerekirse büyür (bkz. PLAN Görev B.2 — buton
                      // etiketi kırpılmaz).
                      if (episode != null)
                        FilledButton(
                          onPressed: () => context.push(
                            '/series/${series.slug}/read/${episode.slug}',
                          ),
                          child: const Text('İlk bölümü oku'),
                        ),
                      if (episode != null) SizedBox(height: tokens.spacing.sm),
                      OutlinedButton(
                        onPressed: () => context.push('/series/${series.slug}'),
                        child: const Text('Seriyi incele'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// En son okunan seri için kompakt "Okumaya devam et" şeridi — hero'nun
/// altında, sonraki bölümlerden önce (bkz. PLAN "keşif" maddesi). Yalnız
/// cihaz-yerel bir kayıt varsa çağıran yer (`_DiscoverContent`) bu widget'ı
/// oluşturur; kayıt yoksa hiç render edilmez (ADR-010 — boş durum/
/// placeholder yok).
class _ContinueReadingStrip extends StatelessWidget {
  const _ContinueReadingStrip({super.key, required this.progress});

  final ReadingProgress progress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final label = '${progress.seriesTitle} · Bölüm ${progress.episodeNumber}';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.md,
        tokens.spacing.md,
        tokens.spacing.md,
        0,
      ),
      child: Semantics(
        button: true,
        label: 'Okumaya devam et: $label',
        child: Material(
          color: tokens.colors.surface2,
          borderRadius: BorderRadius.circular(tokens.radii.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(tokens.radii.md),
            onTap: () => context.push(
              '/series/${progress.seriesSlug}/read/${progress.episodeSlug}',
            ),
            child: Container(
              constraints: BoxConstraints(
                minHeight: tokens.sizes.minTouchTarget,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.md,
                vertical: tokens.spacing.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(tokens.radii.md),
                border: Border.all(color: tokens.colors.line),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.play_circle_outline_rounded,
                    color: tokens.colors.mint,
                  ),
                  SizedBox(width: tokens.spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Okumaya devam et',
                          style: tokens.typography.bodySmall.copyWith(
                            color: tokens.colors.mint,
                          ),
                        ),
                        Text(
                          label,
                          style: tokens.typography.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: tokens.colors.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.tokens,
    this.highlight = false,
  });

  final String text;
  final AppTokens tokens;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.sm,
        vertical: tokens.spacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: highlight
            ? tokens.colors.mint
            : tokens.colors.surface2.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(tokens.radii.pill),
        border: highlight ? null : Border.all(color: tokens.colors.line),
      ),
      child: Text(
        text,
        style: tokens.typography.bodySmall.copyWith(
          color: highlight ? tokens.colors.background : tokens.colors.ink,
        ),
      ),
    );
  }
}
