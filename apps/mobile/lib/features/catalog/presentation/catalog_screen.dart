import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_error_presenter.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../../shared/utils/turkish_search.dart';
import '../../../shared/widgets/home_button.dart';
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
///
/// Durum ve sıralama kontrolleri web referansındaki `CatalogFilterForm`'un
/// (bkz. `app/catalog/CatalogFilterForm.tsx`) "Durum" ve "Sırala" alanlarının
/// Flutter karşılığıdır (kullanıcı bildirimi: "webde filtrelemede sadece
/// arama değil, 3 tane daha filtre vardı" — tür zaten vardı, eksik olan
/// durum ve sıralamaydı). Durum karşılaştırması web'deki ongoing/completed ->
/// Türkçe eşlemesini TEKRARLAMAZ: [SeriesSummary.status] sözleşmesi zaten tam
/// "Devam Ediyor"/"Tamamlandı" string'lerini taşır (bkz.
/// `core/contracts/generated/series_summary.dart` — "Bilinen değer kümesi"
/// yorumu), bu yüzden doğrudan karşılaştırılır. Sıralamada "Son güncellenen"
/// (varsayılan) seçiliyken HİÇBİR yeniden sıralama yapılmaz: `GET
/// /api/catalog` zaten `ORDER BY is_featured DESC, updated_at DESC, title
/// COLLATE NOCASE` ile gelir (bkz. `app/lib/content-repository.ts` ~satır
/// 278) ve web'in kendisi de `sort === "updated"` için ayrı bir yeniden
/// sıralama yapmaz (bkz. aynı dosya satır 492-493) — istemci bu doğal API
/// sırasını yeniden hesaplamaz/bozmaz. "Ada göre" sıralaması tam NFKD/
/// tr-locale collation yerine, dosyada zaten belgelenmiş
/// `normalizeCatalogSearch` katlama tablosunu (bkz.
/// `shared/utils/turkish_search.dart` — "NFKD sapması" notu) karşılaştırma
/// anahtarı olarak yeniden kullanır; bu, yeni bir yaklaşım icadı değil, aynı
/// belgelenmiş sapmanın tekrarıdır.
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
  String? _selectedStatus;
  _CatalogSort _sort = _CatalogSort.updated;

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

  void _selectStatus(String? status) {
    setState(() => _selectedStatus = status);
  }

  void _selectSort(_CatalogSort sort) {
    setState(() => _sort = sort);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final discovery = ref.watch(discoveryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Katalog'),
        actions: const [HomeButton()],
      ),
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

            // 1) Filtrele: arama + tür + durum, AND mantığıyla (web'in
            // `CatalogFilterForm` referansındaki davranışıyla aynı sıra).
            var filtered = filterSeriesByGenre(response.series, _selectedGenre);
            final needle = normalizeCatalogSearch(_query);
            if (needle.isNotEmpty) {
              filtered = filtered
                  .where((series) => normalizeCatalogSearch(_catalogSearchHaystack(series))
                      .contains(needle))
                  .toList(growable: false);
            }
            filtered = _filterSeriesByStatus(filtered, _selectedStatus);
            // 2) Sırala: filtrelenmiş sonuç üzerinde, en son (bkz. sınıf
            // başlığı doc yorumu — "Son güncellenen" API sırasını korur).
            filtered = _sortSeries(filtered, _sort);

            return _CatalogContent(
              searchController: _searchController,
              genres: genres,
              selectedGenre: _selectedGenre,
              onSelectGenre: _selectGenre,
              selectedStatus: _selectedStatus,
              onSelectStatus: _selectStatus,
              sort: _sort,
              onSelectSort: _selectSort,
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

/// Web'in `CatalogFilterForm` "Sırala" alanının (bkz.
/// `app/catalog/CatalogFilterForm.tsx`) üç seçeneği. [updated] varsayılan
/// değerdir ve web'deki `sort` query param'ının varsayılanıyla eşleşir.
enum _CatalogSort { updated, rating, title }

extension on _CatalogSort {
  String get label => switch (this) {
        _CatalogSort.updated => 'Son güncellenen',
        _CatalogSort.rating => 'Puana göre',
        _CatalogSort.title => 'Ada göre',
      };
}

/// Web'in `CatalogFilterForm` "Durum" alanının Flutter karşılığı. `null`
/// "Tümü" (filtre yok) anlamına gelir; diğer iki değer
/// [SeriesSummary.status] ile DOĞRUDAN karşılaştırılır — web'deki gibi ayrı
/// bir ongoing/completed -> Türkçe eşlemesi burada YOK, çünkü sözleşme
/// zaten tam Türkçe durum string'ini taşıyor (bkz.
/// `core/contracts/generated/series_summary.dart`).
List<SeriesSummary> _filterSeriesByStatus(
  List<SeriesSummary> series,
  String? status,
) {
  if (status == null) return series;
  return series
      .where((item) => item.status == status)
      .toList(growable: false);
}

/// Seçili sıralamayı filtrelenmiş listeye uygular. [_CatalogSort.updated]
/// (varsayılan) için liste OLDUĞU GİBİ döner: `GET /api/catalog` cevabı
/// zaten `ORDER BY is_featured DESC, updated_at DESC, title COLLATE NOCASE`
/// ile gelir (bkz. `app/lib/content-repository.ts` ~satır 278) ve web'in
/// kendisi de `sort === "updated"` için ayrı bir yeniden sıralama yapmaz
/// (bkz. aynı dosya satır 492-493); istemci bu doğal API sırasını asla
/// yeniden hesaplamaz ya da bozmaz — bu yüzden burada varsayılan durum için
/// KASITLI olarak hiçbir `.sort()` çağrısı yok. [_CatalogSort.rating] ve
/// [_CatalogSort.title], web'in `fallbackCatalogSearch` sıralama mantığıyla
/// (aynı dosya) aynı iki alanlı karşılaştırmayı kullanır: birincil alan
/// eşitse `slug` ile kararlı/deterministik biçimde tamamlanır.
List<SeriesSummary> _sortSeries(List<SeriesSummary> series, _CatalogSort sort) {
  if (sort == _CatalogSort.updated) return series;

  final sorted = series.toList(growable: false);
  if (sort == _CatalogSort.rating) {
    sorted.sort((a, b) {
      final byRating = b.rating.compareTo(a.rating);
      return byRating != 0 ? byRating : a.slug.compareTo(b.slug);
    });
    return sorted;
  }

  // `title`: web `a.title.localeCompare(b.title, "tr")` kullanır. Dart'ın
  // çekirdek kütüphanesinde tam tr-locale collation yoktur ve AGENTS.md
  // gerekçesiz yeni bağımlılık eklemeyi yasaklar (bkz.
  // `shared/utils/turkish_search.dart` başlığındaki "NFKD sapması" notu —
  // aynı gerekçe burada da geçerli). Bu yüzden yeni bir yaklaşım icat
  // etmek yerine dosyadaki mevcut, zaten belgelenmiş katlama tablosu
  // (`normalizeCatalogSearch`) karşılaştırma anahtarı olarak yeniden
  // kullanılır.
  sorted.sort((a, b) {
    final byTitle = normalizeCatalogSearch(a.title)
        .compareTo(normalizeCatalogSearch(b.title));
    return byTitle != 0 ? byTitle : a.slug.compareTo(b.slug);
  });
  return sorted;
}

class _CatalogContent extends StatelessWidget {
  const _CatalogContent({
    required this.searchController,
    required this.genres,
    required this.selectedGenre,
    required this.onSelectGenre,
    required this.selectedStatus,
    required this.onSelectStatus,
    required this.sort,
    required this.onSelectSort,
    required this.series,
    required this.hasAnySeries,
    required this.onRefresh,
  });

  final TextEditingController searchController;
  final List<String> genres;
  final String? selectedGenre;
  final ValueChanged<String?> onSelectGenre;
  final String? selectedStatus;
  final ValueChanged<String?> onSelectStatus;
  final _CatalogSort sort;
  final ValueChanged<_CatalogSort> onSelectSort;
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
          SliverToBoxAdapter(
            child: _CatalogFilterSection(
              label: 'Durum',
              topPadding: tokens.spacing.sm,
              child: _CatalogStatusBar(
                selected: selectedStatus,
                onSelect: onSelectStatus,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _CatalogFilterSection(
              label: 'Sırala',
              topPadding: tokens.spacing.sm,
              child: _CatalogSortBar(
                selected: sort,
                onSelect: onSelectSort,
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

/// Durum ve sıralama çubuklarının üstündeki küçük etiket (web'in
/// `<label><span>Durum</span>...` / `<span>Sırala</span>` başlıklarının
/// erişilebilir eşdeğeri) + çubuğun kendisi.
///
/// Yalnız DİKEY (`topPadding`) bir boşluk ekler; yatay boşluğu KASITLI
/// olarak eklemez, çünkü [child] (bkz. [_CatalogStatusBar], [_CatalogSortBar]
/// — [_CatalogGenreBar] ile aynı desen) zaten kendi yatay `ListView`
/// padding'ini taşıyor. İkisini üst üste eklemek chip'leri ekranın
/// solundan/sağından taşırıp dokunma testlerinde hit-test dışına düşmesine
/// yol açardı (bkz. görev raporundaki "Kalan risk/varsayım" — bu tam olarak
/// ilk taslakta yakalanan hataydı).
class _CatalogFilterSection extends StatelessWidget {
  const _CatalogFilterSection({
    required this.label,
    required this.topPadding,
    required this.child,
  });

  final String label;
  final double topPadding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: tokens.spacing.md,
              bottom: tokens.spacing.xs,
            ),
            child: Text(
              label,
              style: tokens.typography.bodySmall.copyWith(
                color: tokens.colors.muted,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _CatalogStatusBar extends StatelessWidget {
  const _CatalogStatusBar({required this.selected, required this.onSelect});

  final String? selected;
  final ValueChanged<String?> onSelect;

  /// [SeriesSummary.status]'ün taşıdığı tam Türkçe değerler (bkz.
  /// `core/contracts/generated/series_summary.dart` — "Bilinen değer
  /// kümesi" yorumu). Web'deki ongoing/completed sözlük anahtarları burada
  /// KASITLI olarak YOK.
  static const _statuses = <String>['Devam Ediyor', 'Tamamlandı'];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SizedBox(
      height: tokens.sizes.minTouchTarget,
      child: ListView.separated(
        key: const ValueKey('catalog-status-bar-scrollable'),
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.md),
        itemCount: _statuses.length + 1,
        separatorBuilder: (context, index) => SizedBox(width: tokens.spacing.sm),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CatalogChip(
              key: const ValueKey('catalog-status-chip-all'),
              label: 'Tümü',
              isSelected: selected == null,
              semanticsLabel: 'Tümü durumuna göre filtrele',
              onTap: () => onSelect(null),
            );
          }
          final status = _statuses[index - 1];
          final isSelected = selected == status;
          return _CatalogChip(
            key: ValueKey('catalog-status-chip-$status'),
            label: status,
            isSelected: isSelected,
            semanticsLabel: '$status durumuna göre filtrele',
            onTap: () => onSelect(isSelected ? null : status),
          );
        },
      ),
    );
  }
}

class _CatalogSortBar extends StatelessWidget {
  const _CatalogSortBar({required this.selected, required this.onSelect});

  final _CatalogSort selected;
  final ValueChanged<_CatalogSort> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SizedBox(
      height: tokens.sizes.minTouchTarget,
      child: ListView.separated(
        key: const ValueKey('catalog-sort-bar-scrollable'),
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.md),
        itemCount: _CatalogSort.values.length,
        separatorBuilder: (context, index) => SizedBox(width: tokens.spacing.sm),
        itemBuilder: (context, index) {
          final option = _CatalogSort.values[index];
          final isSelected = selected == option;
          return _CatalogChip(
            key: ValueKey('catalog-sort-chip-${option.name}'),
            label: option.label,
            isSelected: isSelected,
            semanticsLabel: '${option.label} sıralamasını uygula',
            // Sıralamanın her zaman tam olarak bir aktif değeri vardır (web
            // `<select>`'in aksine "seçimi kaldır" durumu yok); bu yüzden
            // tür/durum çubuklarındaki toggle-to-null davranışı burada
            // KASITLI olarak yok — seçili chip'e tekrar dokunmak no-op'tur.
            onTap: () => onSelect(option),
          );
        },
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
            return _CatalogChip(
              key: const ValueKey('catalog-genre-chip-all'),
              label: 'Tümü',
              isSelected: selected == null,
              semanticsLabel: 'Tümü türüne göre filtrele',
              onTap: () => onSelect(null),
            );
          }
          final genre = genres[index - 1];
          final isSelected = selected == genre;
          return _CatalogChip(
            key: ValueKey('catalog-genre-chip-$genre'),
            label: genre,
            isSelected: isSelected,
            semanticsLabel: '$genre türüne göre filtrele',
            onTap: () => onSelect(isSelected ? null : genre),
          );
        },
      ),
    );
  }
}

/// Tür, durum ve sıralama çubuklarının paylaştığı tek chip görseli (bkz.
/// [_CatalogGenreBar], [_CatalogStatusBar], [_CatalogSortBar]). Yalnız
/// erişilebilir etiket metni ([semanticsLabel]) çağıran tarafından
/// özelleştirilir; görsel dil (renk, kenarlık, dokunma hedefi) üçü için
/// birebir aynıdır.
class _CatalogChip extends StatelessWidget {
  const _CatalogChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.semanticsLabel,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticsLabel,
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
