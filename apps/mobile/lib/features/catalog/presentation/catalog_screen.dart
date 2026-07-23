import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_error_presenter.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../../shared/utils/turkish_search.dart';
import '../../../shared/widgets/series_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../discover/presentation/discover_filters.dart';
import '../../discover/presentation/discover_providers.dart';
import '../../discover/presentation/discover_screen.dart'
    show discoverGridColumnsForWidth, seriesCardMainAxisExtent;
import '../../discovery/presentation/discovery_providers.dart';

/// Tam katalog ekranı (`/catalog`, bkz. PLAN Görev 5): arama + tür filtresi
/// + doğal mobil lazy ızgara. Web'in 8/16/32 sayfa boyutu ve numaralı
/// sayfalama kontrolleri kasıtlı olarak KOPYALANMADI (bkz.
/// docs/mobile-handoff.md madde 7 — "Mobil doğal lazy grid/list kullanır");
/// `GET /api/catalog` zaten TÜM yayınlanmış serileri tek cevapta döndürür,
/// bu yüzden istemci tarafında ek bir sayfalama isteği yok — yalnız
/// [SliverGrid]'in kendi lazy (yalnız görünür + önbellek payındaki hücreleri
/// inşa eden) davranışı kullanılır.
///
/// Tür filtre chip'leri `GET /api/discovery`'nin `genres` alanından gelir
/// (bkz. [discoveryProvider]), tam kataloğun istemci tarafında yeniden
/// toplanmasından DEĞİL. Bunun nedeni: web tarafında bu iki uç aynı temel
/// sorguya dayanır (`listPublishedGenres` da `listPublishedSeries` ile aynı
/// "yayınlanmış ve en az bir yayınlanmış bölümü olan seri" kümesini tarar,
/// bkz. `app/lib/content-repository.ts`), yani iki kaynak birbirinden asla
/// sapmaz; tek kaynaktan okumak ana sayfadaki açılır tür dizini (bkz.
/// `GenreDisclosure`) ile BİREBİR aynı listeyi garanti eder ve katalog
/// ekranının kendi tür toplama mantığını tekrar etmesini önler. Bu yüzden
/// `discover_filters.dart`'taki eski `uniqueGenres` (tam katalogdan istemci
/// tarafı türetme) kaldırıldı — bkz. o dosyanın doc yorumu.
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key, this.initialGenre});

  /// Ana sayfadaki açılır tür dizininden (bkz. `GenreDisclosure`) veya bir
  /// gelecekteki deep-link'ten önceden seçili gelen tür (varsa).
  final String? initialGenre;

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _searchController = TextEditingController();
  String? _selectedGenre;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedGenre = widget.initialGenre;
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectGenre(String? genre) {
    setState(() => _selectedGenre = genre);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final discovery = ref.watch(discoveryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Katalog')),
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
              return const AppEmptyView(
                message: 'Henüz yayınlanmış bir seri yok.',
              );
            }

            // `genres` yalnız yardımcı bir filtre yüzeyidir; keşif akışı
            // henüz yüklenmemiş/hata vermiş olsa bile katalog arama ve
            // ızgarası çalışmaya devam eder (bkz. yukarıdaki doc — bu
            // ikincil veri kaynağının kendi hata/boş durumu tüm ekranı
            // bloklamaz).
            final genres = discovery.asData?.value.genres ?? const <String>[];

            var filtered = filterSeriesByGenre(response.series, _selectedGenre);
            final needle = normalizeCatalogSearch(_query);
            if (needle.isNotEmpty) {
              filtered = filtered
                  .where((series) => normalizeCatalogSearch(_catalogSearchHaystack(series))
                      .contains(needle))
                  .toList(growable: false);
            }

            return _CatalogContent(
              searchController: _searchController,
              genres: genres,
              selectedGenre: _selectedGenre,
              onSelectGenre: _selectGenre,
              series: filtered,
              hasAnySeries: response.series.isNotEmpty,
              onRefresh: () => ref.refresh(catalogProvider.future),
            );
          },
        ),
      ),
    );
  }
}

/// Web'in `catalogSearchText` fonksiyonuyla aynı alan birleşimi (bkz.
/// `app/lib/content-repository.ts` — title/creator/eyebrow/description/
/// genres). Sunucu tarafında önceden hesaplanmış bir `searchText` alanı
/// `SeriesSummary` sözleşmesinde YOK; bu yüzden aynı haystack istemci
/// tarafında aynı alan sırasıyla yeniden kurulur.
String _catalogSearchHaystack(SeriesSummary series) {
  return [
    series.title,
    series.creator,
    series.eyebrow,
    series.description,
    ...series.genres,
  ].join(' ');
}

class _CatalogContent extends StatelessWidget {
  const _CatalogContent({
    required this.searchController,
    required this.genres,
    required this.selectedGenre,
    required this.onSelectGenre,
    required this.series,
    required this.hasAnySeries,
    required this.onRefresh,
  });

  final TextEditingController searchController;
  final List<String> genres;
  final String? selectedGenre;
  final ValueChanged<String?> onSelectGenre;
  final List<SeriesSummary> series;
  final bool hasAnySeries;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final width = MediaQuery.sizeOf(context).width;
    final columns = discoverGridColumnsForWidth(width);
    final gridContentWidth = width - tokens.spacing.md * 2;
    final columnWidth =
        (gridContentWidth - (columns - 1) * tokens.spacing.md) / columns;
    final mainAxisExtent = seriesCardMainAxisExtent(context, columnWidth);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.md,
                tokens.spacing.md,
                tokens.spacing.md,
                0,
              ),
              child: TextField(
                key: const ValueKey('catalog-search-field'),
                controller: searchController,
                textInputAction: TextInputAction.search,
                style: tokens.typography.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'Ada, üreticiye veya türe göre ara',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Aramayı temizle',
                          onPressed: searchController.clear,
                        ),
                  filled: true,
                  fillColor: tokens.colors.surface2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.radii.md),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          if (genres.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: tokens.spacing.sm),
                child: _CatalogGenreBar(
                  genres: genres,
                  selected: selectedGenre,
                  onSelect: onSelectGenre,
                ),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.all(tokens.spacing.md),
            sliver: series.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyView(
                      message: hasAnySeries
                          ? 'Bu arama veya türde henüz yayınlanmış bir seri yok.'
                          : 'Henüz yayınlanmış bir seri yok.',
                    ),
                  )
                : SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: tokens.spacing.md,
                      crossAxisSpacing: tokens.spacing.md,
                      mainAxisExtent: mainAxisExtent,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = series[index];
                      return SeriesCard(
                        key: ValueKey('series-card-${item.slug}'),
                        series: SeriesCardData.fromSeriesSummary(item),
                        onTap: () => context.push('/series/${item.slug}'),
                      );
                    }, childCount: series.length),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CatalogGenreBar extends StatelessWidget {
  const _CatalogGenreBar({
    required this.genres,
    required this.selected,
    required this.onSelect,
  });

  final List<String> genres;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SizedBox(
      height: tokens.sizes.minTouchTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.md),
        itemCount: genres.length + 1,
        separatorBuilder: (context, index) => SizedBox(width: tokens.spacing.sm),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CatalogGenreChip(
              key: const ValueKey('catalog-genre-chip-all'),
              label: 'Tümü',
              isSelected: selected == null,
              onTap: () => onSelect(null),
            );
          }
          final genre = genres[index - 1];
          final isSelected = selected == genre;
          return _CatalogGenreChip(
            key: ValueKey('catalog-genre-chip-$genre'),
            label: genre,
            isSelected: isSelected,
            onTap: () => onSelect(isSelected ? null : genre),
          );
        },
      ),
    );
  }
}

class _CatalogGenreChip extends StatelessWidget {
  const _CatalogGenreChip({
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
