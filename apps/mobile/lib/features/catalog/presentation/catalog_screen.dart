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
/// Tür, durum ve sıralama filtreleri web'in `CatalogFilterForm` (bkz.
/// `app/catalog/CatalogFilterForm.tsx`) referansındaki gibi ÜÇ AYRI seçim
/// alanı olarak render edilir — arama kutusunun hemen altında, bu sırayla
/// (kullanıcı bildirimi: "webdeki gibi dropdowndan seçmeli olmasını
/// istiyorum"). Kapalı haldeki alanlar `DropdownButtonFormField` KULLANMAZ:
/// Flutter'ın standart `DropdownButton` menüsü açılırken seçili öğeyi
/// dokunma noktasının olduğu yere ortalar ve listeyi oradan yukarı/aşağı
/// büyütür — bu da AppBar'ı kapatan ve her açılışta farklı bir konumdan
/// başlayan tutarsız bir görünüme yol açar (kullanıcı bildirimi: "hangisine
/// bastıysam o pozisyonda eşit geliyor... çalışma prensibini beğenmedim").
///
/// İlk düzeltme `showModalBottomSheet` ile ekranın altından açılan bir seçim
/// sayfasıydı; bu, konum tutarsızlığını çözdü ama kullanıcı bunu da doğru
/// bulmadı ("ekranın en altından açılması saçma değil mi"). Araştırma
/// (Material Design 3 "Menus" bileşen dokümantasyonu, bkz.
/// https://m3.material.io/components/menus/overview ve Android'in
/// "exposed dropdown menu" deseni — Gmail'in "Taşı", Google Drive'ın
/// "Sırala" filtreleri gibi kısa liste seçicilerinde kullanılan standart)
/// şunu doğruladı: kısa/orta uzunluktaki filtre seçicileri için doğru desen
/// alanın TAM ALTINA sabitlenen, dokunulan noktadan/önceki seçimden bağımsız
/// bir açılır menüdür — tam ekran alt sayfa (bottom sheet) yalnız arama
/// içeren uzun/birincil seçiciler (örn. ülke seçici) için uygundur. Flutter
/// tarafında bu desenin karşılığı `DropdownButton`'ın YERİNE 3.7'de eklenen
/// Material 3 `DropdownMenu` widget'ıdır (bkz. [_CatalogDropdownField] doc
/// yorumu) — `MenuAnchor` üzerine kuruludur ve menüyü her zaman anchor
/// widget'ın (bu alanın) hemen altına (yer yoksa üstüne çevirerek) sabit
/// biçimde açar; `DropdownButton`'ın "seçili öğeyi dokunma noktasında
/// tutma" davranışı YOKTUR. State ve filtreleme mantığı (aşağıdaki
/// `_selectedGenre`/`_selectedStatus`/`_sort` ve
/// `_filterSeriesByStatus`/`_sortSeries`) bu ikinci değişiklikte de
/// DEĞİŞMEDİ, yalnız seçim arayüzü değişti.
///
/// Tür filtre seçenekleri `GET /api/discovery`'nin `genres` alanından gelir
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
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.md,
                tokens.spacing.sm,
                tokens.spacing.md,
                0,
              ),
              // Web'in `CatalogFilterForm` (bkz. `app/catalog/
              // CatalogFilterForm.tsx`) dikey form alanları gibi: Tür, Durum
              // ve Sırala dropdown'ları arama kutusunun hemen altında, bu
              // sırayla, dikey olarak art arda. Tür yalnız `genres`
              // yüklüyken gösterilir (bkz. sınıf başlığı doc yorumu — bu
              // görünürlük koşulu chip'ten dropdown'a geçişte DEĞİŞMEDİ).
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (genres.isNotEmpty) ...[
                    _CatalogGenreDropdown(
                      genres: genres,
                      selected: selectedGenre,
                      onSelect: onSelectGenre,
                    ),
                    SizedBox(height: tokens.spacing.sm),
                  ],
                  _CatalogStatusDropdown(
                    selected: selectedStatus,
                    onSelect: onSelectStatus,
                  ),
                  SizedBox(height: tokens.spacing.sm),
                  _CatalogSortDropdown(selected: sort, onSelect: onSelectSort),
                ],
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

/// Tek bir seçenek: [_CatalogDropdownField]'ın altında açılan menüdeki bir
/// satırı temsil eder. `DropdownMenuEntry` (bkz. Flutter SDK) kendi başına
/// bir anahtar (`Key`) taşımaz; test'ler bu yüzden seçenekleri
/// [_CatalogDropdownField]'ın ürettiği `MenuItemButton`ları GÖRÜNÜR
/// ETİKETLERİNDEN bulur (bkz. `catalog_screen_test.dart` —
/// `find.widgetWithText(MenuItemButton, label)`), önceki taslaktaki
/// (bottom sheet) sabit `testKey`'ler yerine.
class _CatalogDropdownOption<T> {
  const _CatalogDropdownOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Web'in `CatalogFilterForm` (bkz. `app/catalog/CatalogFilterForm.tsx`)
/// Tür/Durum/Sırala `<select>` alanlarının Flutter karşılığı: üç filtre
/// [_CatalogGenreDropdown], [_CatalogStatusDropdown] ve [_CatalogSortDropdown]
/// bu tek sarmalayıcıyı paylaşır — yalnız etiket/seçenek/callback her biri
/// için özelleşir, görsel dil üçü için birebir aynıdır.
///
/// Bu alan Material 3'ün `DropdownMenu` widget'ını (bkz. Flutter SDK
/// `dropdown_menu.dart`, 3.7'de eklendi) kullanır — `DropdownButtonFormField`
/// (eski `DropdownButton` tabanlı, "seçili öğeyi dokunma noktasında tutan"
/// konumlandırması yüzünden terk edildi) DEĞİL, ve tam ekran
/// `showModalBottomSheet` (ilk düzeltmede kullanıldı, kullanıcı "ekranın en
/// altından açılması saçma" diye reddetti) DA DEĞİL. `DropdownMenu`,
/// Material 3'ün "exposed dropdown menu" deseninin (bkz.
/// https://m3.material.io/components/menus/overview — Gmail'in "Taşı",
/// Google Drive'ın "Sırala" gibi kısa filtre seçicilerinde kullanılan
/// standart) doğrudan Flutter karşılığıdır: `MenuAnchor` üzerine kuruludur
/// ve menüyü HER ZAMAN bu alanın hemen altına (ekranda yer yoksa üstüne
/// çevirerek) açar — ne dokunma noktasına ne de önceki seçime göre
/// KONUMLANMAZ, ne de ekranın tamamını kaplayan bir sayfa açar.
///
/// `key: ValueKey(value)`: `DropdownMenu`'nün kendi state'i
/// `initialSelection`'ı yalnız ilk `initState`'te okur; dışarıdan (örn.
/// `_selectGenre` ile) [value] değiştiğinde widget'ın GÖVDESİ aynı `State`'i
/// koruyarak yeniden build edilirse kapalı alanın gösterdiği metin ESKİ
/// seçimde takılı kalabilir. Anahtarı seçilen değere bağlamak, değer her
/// değiştiğinde Flutter'a eski `State`'i atıp SIFIRDAN bir `DropdownMenu`
/// kurdurur (`initState` yeniden çalışır, `initialSelection` güncel
/// [value]'yu okur) — bu, kontrolün her zaman dışarıdaki gerçek durumla
/// birebir senkron kalmasını Flutter sürüm/iç uygulama detaylarına
/// güvenmeden garanti eder.
class _CatalogDropdownField<T> extends StatelessWidget {
  const _CatalogDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<_CatalogDropdownOption<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final borderRadius = BorderRadius.circular(tokens.radii.md);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // `DropdownMenu.label`'ın Material yüzen etiketi KASITLI olarak
        // KULLANILMIYOR: bu etiket kendi kapladığı alanı widget'ın raporladığı
        // yüksekliğe DAHİL ETMEZ — kutunun üst kenarının biraz üstüne taşarak
        // çizilir (bkz. Flutter SDK `dropdown_menu.dart`). Üç alan
        // `Column`'da art arda dururken bu, HER alanın etiketinin bir
        // ÖNCEKİ alanın alt kenarına binmesine yol açtı (kullanıcı
        // bildirimi: "bu dropdownların üstüne taşan tür durum sırala ne
        // öyle?" — ekran görüntüsüyle doğrulandı). Bunun yerine etiket
        // normal `Column` akışında, alanın ÜSTÜNDE ayrı bir `Text` olarak
        // durur — hiçbir kutunun sınırını aşamaz.
        Text(
          label,
          style: tokens.typography.bodySmall.copyWith(color: tokens.colors.muted),
        ),
        SizedBox(height: tokens.spacing.xs),
        ConstrainedBox(
          // mobile-handoff.md'nin "dokunma hedefleri en az 44x44" kuralı.
          constraints: BoxConstraints(minHeight: tokens.sizes.minTouchTarget),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return DropdownMenu<T>(
                width: constraints.maxWidth,
                initialSelection: value,
                // Bu bir serbest metin arama kutusu değil, web
                // `<select>`'inin karşılığı bir seçicidir: dokunma klavye
                // açmaz, yazı filtrelemez — yalnız menüyü açar.
                requestFocusOnTap: false,
                enableFilter: false,
                enableSearch: false,
                textStyle: tokens.typography.bodyLarge,
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: tokens.colors.surface2,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.md,
                    vertical: tokens.spacing.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: borderRadius,
                    borderSide: BorderSide.none,
                  ),
                ),
                menuStyle: MenuStyle(
                  backgroundColor: WidgetStatePropertyAll(tokens.colors.surface2),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(borderRadius: borderRadius),
                  ),
                  elevation: const WidgetStatePropertyAll(4),
                ),
                // `DropdownMenu<T>.onSelected`'ın imzası `ValueChanged<T?>?`'dir
                // (T ne olursa olsun) ama yalnız GERÇEK bir [items] girişine
                // dokunulduğunda çağrılır — asla kendiliğinden "seçim yok"
                // anlamında null ile tetiklenmez. Bu yüzden `selected`,
                // T=String? olan Tür/Durum alanlarında MEŞRU biçimde null
                // OLABİLİR (Tüm türler/Tümü girişi tam olarak budur) — `if
                // (selected != null)` gibi bir koruma bu null'u YANLIŞLIKLA
                // atardı (kullanıcı bildirimi ile bulunan gerçek hata:
                // "Tümü" seçmek durum filtresini KALDIRMIYORDU). `as T` —
                // T=_CatalogSort (nullable olmayan) için çalışma zamanında
                // hep gerçek, null-olmayan bir değer taşıdığından
                // güvenlidir.
                onSelected: (selected) => onChanged(selected as T),
                dropdownMenuEntries: [
                  for (final item in items)
                    DropdownMenuEntry<T>(
                      value: item.value,
                      label: item.label,
                      trailingIcon: item.value == value
                          ? Icon(Icons.check, color: tokens.colors.mint)
                          : null,
                      style: MenuItemButton.styleFrom(
                        foregroundColor: item.value == value
                            ? tokens.colors.mint
                            : tokens.colors.ink,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Web'in "Tür" `<select>`'inin karşılığı (bkz. [_CatalogDropdownField] doc
/// yorumu). Seçenek kaynağı `GET /api/discovery`'nin `genres` alanıdır
/// (bkz. bu dosyanın başındaki sınıf doc yorumu) — tam kataloğun istemci
/// tarafı türetmesi DEĞİL.
class _CatalogGenreDropdown extends StatelessWidget {
  const _CatalogGenreDropdown({
    required this.genres,
    required this.selected,
    required this.onSelect,
  });

  final List<String> genres;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return _CatalogDropdownField<String?>(
      key: const ValueKey('catalog-genre-dropdown'),
      label: 'Tür',
      value: selected,
      onChanged: onSelect,
      items: [
        const _CatalogDropdownOption<String?>(value: null, label: 'Tüm türler'),
        ...genres.map(
          (genre) => _CatalogDropdownOption<String?>(value: genre, label: genre),
        ),
      ],
    );
  }
}

/// Web'in "Durum" `<select>`'inin karşılığı (bkz. [_CatalogDropdownField]
/// doc yorumu). [SeriesSummary.status]'ün taşıdığı tam Türkçe değerler
/// kullanılır (bkz. `core/contracts/generated/series_summary.dart` —
/// "Bilinen değer kümesi" yorumu); web'deki ongoing/completed sözlük
/// anahtarları burada KASITLI olarak YOK.
class _CatalogStatusDropdown extends StatelessWidget {
  const _CatalogStatusDropdown({required this.selected, required this.onSelect});

  final String? selected;
  final ValueChanged<String?> onSelect;

  static const _statuses = <String>['Devam Ediyor', 'Tamamlandı'];

  @override
  Widget build(BuildContext context) {
    return _CatalogDropdownField<String?>(
      key: const ValueKey('catalog-status-dropdown'),
      label: 'Durum',
      value: selected,
      onChanged: onSelect,
      items: [
        const _CatalogDropdownOption<String?>(value: null, label: 'Tümü'),
        ..._statuses.map(
          (status) => _CatalogDropdownOption<String?>(value: status, label: status),
        ),
      ],
    );
  }
}

/// Web'in "Sırala" `<select>`'inin karşılığı (bkz. [_CatalogDropdownField]
/// doc yorumu). Sıralamanın her zaman tam olarak bir aktif değeri vardır
/// (web `<select>`'in aksine "seçimi kaldır" durumu yok); bu yüzden
/// tür/durum dropdown'larındaki `null` seçeneği burada KASITLI olarak yok.
class _CatalogSortDropdown extends StatelessWidget {
  const _CatalogSortDropdown({required this.selected, required this.onSelect});

  final _CatalogSort selected;
  final ValueChanged<_CatalogSort> onSelect;

  @override
  Widget build(BuildContext context) {
    return _CatalogDropdownField<_CatalogSort>(
      key: const ValueKey('catalog-sort-dropdown'),
      label: 'Sırala',
      value: selected,
      onChanged: onSelect,
      items: _CatalogSort.values
          .map(
            (option) =>
                _CatalogDropdownOption<_CatalogSort>(value: option, label: option.label),
          )
          .toList(growable: false),
    );
  }
}
