import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_error_presenter.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../../shared/widgets/series_card.dart';
import '../../../shared/widgets/state_views.dart';
import 'discover_filters.dart';
import 'discover_providers.dart';

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

    return RefreshIndicator(
      onRefresh: () => ref.refresh(catalogProvider.future),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (featured != null)
            SliverToBoxAdapter(
              child: _FeaturedHero(
                key: const ValueKey('featured-hero'),
                series: featured,
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
                      crossAxisCount: 2,
                      mainAxisSpacing: tokens.spacing.md,
                      crossAxisSpacing: tokens.spacing.md,
                      // 3:4 poster + başlık/tür/durum metin bloğu için
                      // yeterli yükseklik (bkz. `SeriesCard`); 0.6 gibi daha
                      // sıkı bir oran metin bloğunda taşmaya yol açıyordu.
                      childAspectRatio: 0.48,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final series = filtered[index];
                        return SeriesCard(
                          key: ValueKey('series-card-${series.slug}'),
                          series: series,
                          onTap: () =>
                              context.push('/series/${series.slug}'),
                        );
                      },
                      childCount: filtered.length,
                    ),
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
class _FeaturedHero extends StatelessWidget {
  const _FeaturedHero({super.key, required this.series});

  final SeriesSummary series;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

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
                  label:
                      'Öne çıkan seri: ${series.title}. ${series.eyebrow}.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: tokens.spacing.xs,
                        runSpacing: tokens.spacing.xs,
                        children: [
                          _Pill(text: 'Haftanın hikâyesi', tokens: tokens, highlight: true),
                          _Pill(text: series.status, tokens: tokens),
                          _Pill(text: '${series.episodeCount} bölüm', tokens: tokens),
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
                      SizedBox(
                        height: tokens.sizes.minTouchTarget,
                        child: FilledButton(
                          onPressed: () =>
                              context.push('/series/${series.slug}'),
                          child: const Text('Seriyi incele'),
                        ),
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

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.tokens, this.highlight = false});

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
        color: highlight ? tokens.colors.mint : tokens.colors.surface2.withValues(alpha: 0.85),
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
        separatorBuilder: (context, index) => SizedBox(width: tokens.spacing.sm),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _GenreChip(
              key: const ValueKey('genre-chip-all'),
              label: 'Tümü',
              isSelected: selected == null,
              onTap: () => ref.read(selectedGenreProvider.notifier).state = null,
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
                color: isSelected ? tokens.colors.background : tokens.colors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
