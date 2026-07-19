import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_error_presenter.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../../features/progress/domain/reading_progress.dart';
import '../../../features/progress/presentation/reading_progress_providers.dart';
import '../../../shared/layout/content_max_width.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../../shared/widgets/series_card.dart';
import '../../../shared/widgets/state_views.dart';
import 'discover_filters.dart';
import 'discover_providers.dart';

/// Keşif ızgarasının kolon sayısını genişliğe göre hesaplar (bkz. PLAN
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

/// Keşif ekranı (`/`): `GET /api/catalog`'dan gelen öne çıkan seri, tür
/// filtreleri ve seri kartları ızgarası (bkz. PLAN Görev 2 ve
/// production-bible.md §7 — kart dili, keskin bilgi hiyerarşisi).
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Panelya')),
      body: SafeArea(
        child: catalog.when(
          loading: () => const AppLoadingView(label: 'Katalog yükleniyor'),
          error: (error, stackTrace) => AppErrorView(
            message: error is ApiException
                ? describeApiException(error)
                : 'Beklenmeyen bir hata oluştu.',
            onRetry: () => ref.invalidate(catalogProvider),
          ),
          data: (response) {
            if (response.series.isEmpty) {
              return RefreshIndicator(
                onRefresh: () => ref.refresh(catalogProvider.future),
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

  final CatalogResponse response;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final genres = uniqueGenres(response.series);
    final selectedGenre = ref.watch(selectedGenreProvider);
    final filtered = filterSeriesByGenre(response.series, selectedGenre);
    // Web ana sayfasıyla aynı ürün dili: bir tür filtresi aktifken öne
    // çıkan seri hero'su gizlenir, yalnız filtrelenmiş sonuçlar gösterilir
    // (bkz. `app/page.tsx` — `!isFiltered` koşulu).
    final featured = selectedGenre == null
        ? findFeaturedSeries(response.series, response.featuredSlug)
        : null;
    // Cihaz-yerel "kaldığın yerden devam et" kaydı (bkz. PLAN, hesapsız
    // özellik). Kayıt yoksa şerit hiç render edilmez — boş durum/placeholder
    // yok (ADR-010).
    final continueReading = ref.watch(mostRecentReadingProgressProvider);

    // Tablet/geniş ekranda ızgara kolon sayısını genişliğe göre uyarlar
    // (bkz. PLAN Görev A.1 — `discoverGridColumnsForWidth`). Hücre
    // genişliği, `SliverPadding`'in yatay boşluğu ve kolonlar arası
    // `crossAxisSpacing` düşüldükten sonra kalan alandan hesaplanır ki
    // `seriesCardMainAxisExtent` doğru poster yüksekliğini türetebilsin.
    final width = MediaQuery.sizeOf(context).width;
    final columns = discoverGridColumnsForWidth(width);
    final gridContentWidth = width - tokens.spacing.md * 2;
    final columnWidth =
        (gridContentWidth - (columns - 1) * tokens.spacing.md) / columns;
    final mainAxisExtent = seriesCardMainAxisExtent(context, columnWidth);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(catalogProvider.future),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (featured != null)
            SliverToBoxAdapter(
              child: CenteredMaxWidth(
                child: _FeaturedHero(
                  key: const ValueKey('featured-hero'),
                  series: featured,
                ),
              ),
            ),
          // Hero'nun ÜSTÜNDE değil altında, ızgaradan önce (bkz. PLAN
          // "keşif" maddesi).
          if (continueReading != null)
            SliverToBoxAdapter(
              child: CenteredMaxWidth(
                child: _ContinueReadingStrip(
                  key: const ValueKey('continue-reading-strip'),
                  progress: continueReading,
                ),
              ),
            ),
          if (genres.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: tokens.spacing.md),
                child: _GenreFilterBar(genres: genres),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.all(tokens.spacing.md),
            sliver: filtered.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: const AppEmptyView(
                      message: 'Bu türde henüz yayınlanmış bir seri yok.',
                    ),
                  )
                : SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: tokens.spacing.md,
                      crossAxisSpacing: tokens.spacing.md,
                      // Sabit `childAspectRatio` yerine metin ölçeğine
                      // duyarlı `mainAxisExtent` (bkz.
                      // `seriesCardMainAxisExtent` — büyük yazı tipinde
                      // taşmayı önler, PLAN Görev B.1).
                      mainAxisExtent: mainAxisExtent,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final series = filtered[index];
                      return SeriesCard(
                        key: ValueKey('series-card-${series.slug}'),
                        series: series,
                        onTap: () => context.push('/series/${series.slug}'),
                      );
                    }, childCount: filtered.length),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Öne çıkan seri hero alanı (`featuredSlug`). Katalogda karşılığı yoksa
/// (findFeaturedSeries `null` dönerse) çağıran yer bu widget'ı hiç
/// oluşturmaz; bu yüzden burada ayrı bir boş/hata durumu yoktur.
/// Hero'nun kapaksız (placeholder) durumunda, ortadaki dekoratif kitap
/// ikonunun (`Icons.auto_stories_outlined`) gösterilmeye devam edebileceği en
/// büyük metin ölçeği. Bunun üzerinde (QA'da gözlenen 1.6+) durum/tür
/// chip'leri ikinci satıra sarar ve alttaki içerik bloğu yükselerek kartın
/// ortasına ulaşır; ikon SALT DEKORATİF olduğundan (bkz. `CoverImage`'daki
/// `Semantics` kapsamı dışı kalması) çakışacağı durumda gizlenmesi, üst üste
/// binmesinden daha doğrudur.
const double _heroDecorativeIconMaxTextScale = 1.5;

class _FeaturedHero extends StatelessWidget {
  const _FeaturedHero({super.key, required this.series});

  final SeriesSummary series;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    // `TextScaler.scale(1.0)` katsayıyı (lineer ölçekleyicilerde) doğrudan
    // verir; `seriesCardMainAxisExtent`'teki satır yüksekliği hesaplamasıyla
    // aynı `MediaQuery.textScalerOf` kaynağını kullanır.
    final textScaleFactor = MediaQuery.textScalerOf(context).scale(1.0);
    final showDecorativeIcon =
        textScaleFactor <= _heroDecorativeIconMaxTextScale;

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
                      FilledButton(
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
/// üstünde değil altında, ızgaradan önce (bkz. PLAN "keşif" maddesi).
/// Yalnız cihaz-yerel bir kayıt varsa çağıran yer (`_DiscoverContent`) bu
/// widget'ı oluşturur; kayıt yoksa hiç render edilmez (ADR-010 — boş
/// durum/placeholder yok).
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

/// Tür filtre chip'leri: katalogdaki tüm serilerin `genres` alanından
/// türetilir (istemci tarafı filtre; arama kapsam dışıdır, bkz. PLAN).
class _GenreFilterBar extends ConsumerWidget {
  const _GenreFilterBar({required this.genres});

  final List<String> genres;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final selected = ref.watch(selectedGenreProvider);

    return SizedBox(
      height: tokens.sizes.minTouchTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.md),
        itemCount: genres.length + 1,
        separatorBuilder: (context, index) =>
            SizedBox(width: tokens.spacing.sm),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _GenreChip(
              key: const ValueKey('genre-chip-all'),
              label: 'Tümü',
              isSelected: selected == null,
              onTap: () =>
                  ref.read(selectedGenreProvider.notifier).state = null,
            );
          }
          final genre = genres[index - 1];
          final isSelected = selected == genre;
          return _GenreChip(
            key: ValueKey('genre-chip-$genre'),
            label: genre,
            isSelected: isSelected,
            onTap: () => ref.read(selectedGenreProvider.notifier).state =
                isSelected ? null : genre,
          );
        },
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label türüne göre filtrele',
      child: Material(
        color: isSelected ? tokens.colors.mint : tokens.colors.surface2,
        borderRadius: BorderRadius.circular(tokens.radii.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radii.pill),
          child: Container(
            constraints: BoxConstraints(minHeight: tokens.sizes.minTouchTarget),
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.md),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radii.pill),
              border: Border.all(
                color: isSelected ? tokens.colors.mint : tokens.colors.line,
              ),
            ),
            child: Text(
              label,
              style: tokens.typography.label.copyWith(
                color: isSelected
                    ? tokens.colors.background
                    : tokens.colors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
