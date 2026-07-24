import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/core/api/api_exception.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/catalog/presentation/catalog_screen.dart';
import 'package:panelya_mobile/features/discover/domain/discover_repository.dart';
import 'package:panelya_mobile/features/discover/presentation/discover_providers.dart';
import 'package:panelya_mobile/features/discovery/domain/discovery_repository.dart';
import 'package:panelya_mobile/features/discovery/presentation/discovery_providers.dart';
import 'package:panelya_mobile/shared/widgets/series_card.dart';

class _FakeCatalogRepository implements DiscoverRepository {
  _FakeCatalogRepository(this._result);

  final Future<CatalogResponse> Function() _result;

  @override
  Future<CatalogResponse> fetchCatalog() => _result();
}

class _FakeDiscoveryRepository implements DiscoveryRepository {
  _FakeDiscoveryRepository(this._result);

  final Future<DiscoveryResponse> Function() _result;

  @override
  Future<DiscoveryResponse> fetchDiscovery() => _result();
}

SeriesSummary _series(
  String slug,
  String title, {
  List<String> genres = const ['Gizem'],
  String creator = 'Panelya Originals',
  String eyebrow = 'Eyebrow',
  String description = 'Description',
  String status = 'Devam Ediyor',
  double rating = 4.5,
}) {
  return SeriesSummary(
    slug: slug,
    title: title,
    eyebrow: eyebrow,
    creator: creator,
    description: description,
    longDescription: 'Long description',
    status: status,
    genres: genres,
    tone: PanelTone.mint,
    updatedAt: 'Bugün',
    rating: rating,
    followers: '1 B',
    episodeCount: 1,
    latestEpisode: null,
  );
}

CatalogResponse _catalogWith(List<SeriesSummary> series) {
  return CatalogResponse(
    schemaVersion: '1.0',
    featuredSlug: series.isEmpty ? null : series.first.slug,
    series: series,
  );
}

DiscoveryResponse _discoveryGenres(List<String> genres) {
  return DiscoveryResponse(
    schemaVersion: '1.0',
    featuredSeries: null,
    featuredFirstEpisode: null,
    genres: genres,
    newSeries: const [],
    latestEpisodes: const [],
  );
}

Finder _seriesCard(String slug) => find.byKey(ValueKey('series-card-$slug'));

final Finder _genreDropdown = find.byKey(
  const ValueKey('catalog-genre-dropdown'),
);
final Finder _statusDropdown = find.byKey(
  const ValueKey('catalog-status-dropdown'),
);
final Finder _sortDropdown = find.byKey(
  const ValueKey('catalog-sort-dropdown'),
);

/// Web'in `<select>` alanlarının Flutter karşılığı olan `DropdownMenu`
/// (bkz. `_CatalogDropdownField` doc yorumu, `catalog_screen.dart`)
/// seçeneklerini `MenuItemButton` olarak render eder; `DropdownMenuEntry`
/// kendi başına bir `Key` taşımadığından seçenekler GÖRÜNÜR ETİKETLERİNDEN
/// bulunur. `MenuItemButton` ile sınırlamak (yalnız `find.text(label)`
/// değil) [SeriesCard] üzerindeki aynı metni (örn. bir tür adı hem menü
/// seçeneği hem de bir kartın tür rozeti olabilir) YANLIŞLIKLA eşleştirmeyi
/// önler.
///
/// `DropdownMenu` HER seçenek için iki `MenuItemButton` inşa eder: biri
/// alanın kapalı genişliğini hesaplamak için görünmez bir ölçüm kopyası
/// (`_DropdownMenuBody` atası altında — bkz. Flutter SDK
/// `dropdown_menu.dart`), diğeri açık menüdeki gerçek/dokunulabilir satır.
/// Bu yüzden varlık kontrolleri `findsOneWidget` DEĞİL `findsWidgets` (en az
/// bir) kullanır. Dokunma hedefi seçmek için ise sıra (`.first`/`.last`)
/// GÜVENİLİR DEĞİLDİR: menü seçili öğeyi görünür kılmak üzere kendi kendine
/// kaydırdığında (Material 3 "exposed dropdown menu" — seçili öğeye otomatik
/// kaydırma — bkz. m3.material.io/components/menus/overview) iki eşleşmenin
/// ağaçtaki SIRASI kararlı kalsa da EKRANDAKİ konumu değişebilir; bu yüzden
/// [_selectDropdownOption] sıraya değil, atalarında `_DropdownMenuBody`
/// OLMAYAN eşleşmeye göre gerçek satırı seçer ve dokunmadan önce
/// `ensureVisible` ile kaydırılmış olabilecek satırı görünür kılar.
Finder _dropdownOption(String label) =>
    find.widgetWithText(MenuItemButton, label);

/// [dropdown] alanına dokunup açılan menüde [label] etiketli GERÇEK (ölçüm
/// kopyası değil) satırı bulup dokunur. Menü bir [Overlay] içinde açıldığı
/// için önce [dropdown] alanının kendisi görünür/inşa edilmiş olmalı.
Future<void> _selectDropdownOption(
  WidgetTester tester,
  Finder dropdown,
  String label,
) async {
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(dropdown);
  await tester.pumpAndSettle();

  Element? real;
  for (final element in _dropdownOption(label).evaluate()) {
    var isMeasurementCopy = false;
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget.runtimeType.toString() == '_DropdownMenuBody') {
        isMeasurementCopy = true;
        return false;
      }
      return true;
    });
    if (!isMeasurementCopy) real = element;
  }
  expect(
    real,
    isNotNull,
    reason: 'No interactive (non-measurement) MenuItemButton found for "$label"',
  );
  final target = find.byElementPredicate((element) => element == real);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// Izgaradaki [SeriesCard]'ların GÖRÜNEN sırasını (dizideki index sırası,
/// grid sütun sayısından bağımsız — bkz. `SliverChildBuilderDelegate`'in
/// index 0..n-1 inşa sırası) döner. Sıralama testlerinde kullanılır.
List<String> _visibleSeriesOrder(WidgetTester tester) {
  return tester
      .widgetList<SeriesCard>(find.byType(SeriesCard))
      .map((card) => card.series.slug)
      .toList(growable: false);
}

Widget _wrap({
  required DiscoverRepository catalogRepository,
  DiscoveryRepository? discoveryRepository,
  String? initialGenre,
}) {
  final router = GoRouter(
    initialLocation: '/catalog',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/catalog',
        builder: (context, state) => CatalogScreen(initialGenre: initialGenre),
      ),
      GoRoute(
        path: '/series/:slug',
        builder: (context, state) =>
            Scaffold(body: Text('SERIES:${state.pathParameters['slug']}')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      discoverRepositoryProvider.overrideWithValue(catalogRepository),
      discoveryRepositoryProvider.overrideWithValue(
        discoveryRepository ??
            _FakeDiscoveryRepository(() async => _discoveryGenres(const [])),
      ),
    ],
    child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
  );
}

void main() {
  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('shows a loading indicator while the catalog loads', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeCatalogRepository(
      () => Future<CatalogResponse>.delayed(
        const Duration(seconds: 1),
        () => _catalogWith(const []),
      ),
    );

    await tester.pumpWidget(_wrap(catalogRepository: repository));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('shows an empty state when the catalog has no series', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeCatalogRepository(
      () async => _catalogWith(const []),
    );

    await tester.pumpWidget(_wrap(catalogRepository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Henüz yayınlanmış bir seri yok.'), findsOneWidget);
  });

  testWidgets('shows an error view with a working retry button', (
    tester,
  ) async {
    usePhoneViewport(tester);
    var attempt = 0;
    final repository = _FakeCatalogRepository(() async {
      attempt += 1;
      if (attempt == 1) throw const NetworkException('bağlantı yok');
      return _catalogWith([_series('gece-vardiyasi', 'Gece Vardiyası')]);
    });

    await tester.pumpWidget(_wrap(catalogRepository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Tekrar dene'), findsOneWidget);
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();

    expect(_seriesCard('gece-vardiyasi'), findsOneWidget);
  });

  testWidgets('shows all series from the full catalog response', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeCatalogRepository(
      () async => _catalogWith([
        _series('gece-vardiyasi', 'Gece Vardiyası'),
        _series('yarinki-ses', 'Yarınki Ses'),
      ]),
    );

    await tester.pumpWidget(_wrap(catalogRepository: repository));
    await tester.pumpAndSettle();

    expect(_seriesCard('gece-vardiyasi'), findsOneWidget);
    expect(_seriesCard('yarinki-ses'), findsOneWidget);
  });

  testWidgets('tapping a card navigates to its series screen', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeCatalogRepository(
      () async => _catalogWith([_series('gece-vardiyasi', 'Gece Vardiyası')]),
    );

    await tester.pumpWidget(_wrap(catalogRepository: repository));
    await tester.pumpAndSettle();

    await tester.tap(_seriesCard('gece-vardiyasi'));
    await tester.pumpAndSettle();

    expect(find.text('SERIES:gece-vardiyasi'), findsOneWidget);
  });

  testWidgets(
    'the app bar offers a home button that navigates to "/" and meets the '
    '44x44 touch target minimum (PLAN Görev 3 — kullanıcı bir seriye/bölüme '
    'girince anasayfaya dönecek bir yol yoktu)',
    (tester) async {
      usePhoneViewport(tester);
      final repository = _FakeCatalogRepository(
        () async => _catalogWith(const []),
      );

      await tester.pumpWidget(_wrap(catalogRepository: repository));
      await tester.pumpAndSettle();

      final homeButton = find.byTooltip('Ana sayfa');
      expect(homeButton, findsOneWidget);
      expect(tester.getSize(homeButton).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(homeButton).height, greaterThanOrEqualTo(44));

      await tester.tap(homeButton);
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
    },
  );

  group('tür filtresi — GET /api/discovery genres alanından gelir', () {
    testWidgets(
      'genre dropdown options come from discoveryResponse.genres, not a '
      'client-side aggregation of the full catalog',
      (tester) async {
        usePhoneViewport(tester);
        final repository = _FakeCatalogRepository(
          () async => _catalogWith([
            _series('a', 'A', genres: const ['Gizem']),
            _series('b', 'B', genres: const ['Dram']),
          ]),
        );
        final discovery = _FakeDiscoveryRepository(
          () async => _discoveryGenres(const ['Gizem', 'Romantizm']),
        );

        await tester.pumpWidget(
          _wrap(catalogRepository: repository, discoveryRepository: discovery),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(_genreDropdown);
        await tester.tap(_genreDropdown);
        await tester.pumpAndSettle();

        expect(_dropdownOption('Tüm türler'), findsWidgets);
        expect(_dropdownOption('Gizem'), findsWidgets);
        expect(_dropdownOption('Romantizm'), findsWidgets);
        // Kataloğun kendi "Dram" türü, discovery `genres`'te YOK ve seçenek
        // olarak da GÖRÜNMEMELİ — kaynak bilerek `discoveryResponse.genres`,
        // tam kataloğun istemci tarafı türetmesi değil (bkz.
        // `catalog_screen.dart` doc yorumu).
        expect(_dropdownOption('Dram'), findsNothing);
      },
    );

    testWidgets(
      'selecting a genre option filters the visible series to that genre',
      (tester) async {
        usePhoneViewport(tester);
        final repository = _FakeCatalogRepository(
          () async => _catalogWith([
            _series('a', 'Seri A', genres: const ['Gizem']),
            _series('b', 'Seri B', genres: const ['Romantizm']),
          ]),
        );
        final discovery = _FakeDiscoveryRepository(
          () async => _discoveryGenres(const ['Gizem', 'Romantizm']),
        );

        await tester.pumpWidget(
          _wrap(catalogRepository: repository, discoveryRepository: discovery),
        );
        await tester.pumpAndSettle();

        await _selectDropdownOption(tester, _genreDropdown, 'Romantizm');

        expect(_seriesCard('b'), findsOneWidget);
        expect(_seriesCard('a'), findsNothing);
      },
    );

    testWidgets(
      'arriving with an initialGenre (from the home disclosure) pre-selects '
      'that chip and pre-filters the grid',
      (tester) async {
        usePhoneViewport(tester);
        final repository = _FakeCatalogRepository(
          () async => _catalogWith([
            _series('a', 'Seri A', genres: const ['Gizem']),
            _series('b', 'Seri B', genres: const ['Romantizm']),
          ]),
        );
        final discovery = _FakeDiscoveryRepository(
          () async => _discoveryGenres(const ['Gizem', 'Romantizm']),
        );

        await tester.pumpWidget(
          _wrap(
            catalogRepository: repository,
            discoveryRepository: discovery,
            initialGenre: 'Romantizm',
          ),
        );
        await tester.pumpAndSettle();

        expect(_seriesCard('b'), findsOneWidget);
        expect(_seriesCard('a'), findsNothing);
      },
    );
  });

  group('Türkçe normalize edilmiş arama (bkz. PLAN Görev 5)', () {
    testWidgets('"İstanbul" query matches a lowercase "istanbul" haystack', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final repository = _FakeCatalogRepository(
        () async => _catalogWith([
          _series(
            'istanbul-hikayesi',
            'istanbul hikayesi',
            description: 'Bir sehir hikayesi',
          ),
          _series('baska-seri', 'Başka Seri', description: 'Alakasız içerik'),
        ]),
      );

      await tester.pumpWidget(_wrap(catalogRepository: repository));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('catalog-search-field')),
        'İstanbul',
      );
      await tester.pumpAndSettle();

      expect(_seriesCard('istanbul-hikayesi'), findsOneWidget);
      expect(_seriesCard('baska-seri'), findsNothing);
    });

    testWidgets('"isik" query matches a title containing "ışık"', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final repository = _FakeCatalogRepository(
        () async => _catalogWith([
          _series('isik-serisi', 'Işık Serisi'),
          _series('baska-seri', 'Başka Seri'),
        ]),
      );

      await tester.pumpWidget(_wrap(catalogRepository: repository));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('catalog-search-field')),
        'isik',
      );
      await tester.pumpAndSettle();

      expect(_seriesCard('isik-serisi'), findsOneWidget);
      expect(_seriesCard('baska-seri'), findsNothing);
    });

    testWidgets('search matches creator/eyebrow/genre text too, not just title', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final repository = _FakeCatalogRepository(
        () async => _catalogWith([
          _series(
            'a',
            'Seri A',
            creator: 'Çılgın Yaratıcı',
            genres: const ['Bilim Kurgu'],
          ),
          _series('b', 'Seri B', creator: 'Sıradan Yaratıcı'),
        ]),
      );

      await tester.pumpWidget(_wrap(catalogRepository: repository));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('catalog-search-field')),
        'cilgin',
      );
      await tester.pumpAndSettle();

      expect(_seriesCard('a'), findsOneWidget);
      expect(_seriesCard('b'), findsNothing);
    });

    testWidgets('an empty search shows every series again', (tester) async {
      usePhoneViewport(tester);
      final repository = _FakeCatalogRepository(
        () async => _catalogWith([
          _series('a', 'Seri A'),
          _series('b', 'Seri B'),
        ]),
      );

      await tester.pumpWidget(_wrap(catalogRepository: repository));
      await tester.pumpAndSettle();

      final searchField = find.byKey(const ValueKey('catalog-search-field'));
      await tester.enterText(searchField, 'hicbir-seyle-eslesmez-xyz');
      await tester.pumpAndSettle();
      expect(_seriesCard('a'), findsNothing);
      expect(_seriesCard('b'), findsNothing);

      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();
      expect(_seriesCard('a'), findsOneWidget);
      expect(_seriesCard('b'), findsOneWidget);
    });
  });

  group('durum filtresi (webde CatalogFilterForm "Durum" alanının karşılığı)', () {
    testWidgets('"Tümü" varsayılan seçilidir ve her durumu gösterir', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final repository = _FakeCatalogRepository(
        () async => _catalogWith([
          _series('devam', 'Devam Eden Seri', status: 'Devam Ediyor'),
          _series('tamam', 'Tamamlanan Seri', status: 'Tamamlandı'),
        ]),
      );

      await tester.pumpWidget(_wrap(catalogRepository: repository));
      await tester.pumpAndSettle();

      await tester.ensureVisible(_statusDropdown);
      await tester.tap(_statusDropdown);
      await tester.pumpAndSettle();

      expect(_dropdownOption('Tümü'), findsWidgets);
      expect(_dropdownOption('Devam Ediyor'), findsWidgets);
      expect(_dropdownOption('Tamamlandı'), findsWidgets);
      expect(_seriesCard('devam'), findsOneWidget);
      expect(_seriesCard('tamam'), findsOneWidget);
    });

    testWidgets('"Tamamlandı" seçmek yalnız o durumdaki serileri gösterir', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final repository = _FakeCatalogRepository(
        () async => _catalogWith([
          _series('devam', 'Devam Eden Seri', status: 'Devam Ediyor'),
          _series('tamam', 'Tamamlanan Seri', status: 'Tamamlandı'),
        ]),
      );

      await tester.pumpWidget(_wrap(catalogRepository: repository));
      await tester.pumpAndSettle();

      await _selectDropdownOption(tester, _statusDropdown, 'Tamamlandı');

      expect(_seriesCard('tamam'), findsOneWidget);
      expect(_seriesCard('devam'), findsNothing);
    });

    testWidgets('"Tümü" seçmek durum filtresini kaldırır (web select\'in aynısı)', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final repository = _FakeCatalogRepository(
        () async => _catalogWith([
          _series('devam', 'Devam Eden Seri', status: 'Devam Ediyor'),
          _series('tamam', 'Tamamlanan Seri', status: 'Tamamlandı'),
        ]),
      );

      await tester.pumpWidget(_wrap(catalogRepository: repository));
      await tester.pumpAndSettle();

      await _selectDropdownOption(tester, _statusDropdown, 'Tamamlandı');
      expect(_seriesCard('devam'), findsNothing);

      await _selectDropdownOption(tester, _statusDropdown, 'Tümü');
      expect(_seriesCard('devam'), findsOneWidget);
      expect(_seriesCard('tamam'), findsOneWidget);
    });

    testWidgets(
      'durum + tür + arama filtreleri AND mantığıyla birlikte uygulanır',
      (tester) async {
        usePhoneViewport(tester);
        final repository = _FakeCatalogRepository(
          () async => _catalogWith([
            _series(
              'a',
              'Gece Vardiyası',
              genres: const ['Gizem'],
              status: 'Devam Ediyor',
            ),
            _series(
              'b',
              'Gece Treni',
              genres: const ['Gizem'],
              status: 'Tamamlandı',
            ),
            _series(
              'c',
              'Gece Yolu',
              genres: const ['Romantizm'],
              status: 'Tamamlandı',
            ),
          ]),
        );
        final discovery = _FakeDiscoveryRepository(
          () async => _discoveryGenres(const ['Gizem', 'Romantizm']),
        );

        await tester.pumpWidget(
          _wrap(catalogRepository: repository, discoveryRepository: discovery),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('catalog-search-field')),
          'gece',
        );
        await tester.pumpAndSettle();
        await _selectDropdownOption(tester, _genreDropdown, 'Gizem');
        await _selectDropdownOption(tester, _statusDropdown, 'Tamamlandı');

        // Yalnız 'b' hem "gece" araması, hem "Gizem" türü, hem de
        // "Tamamlandı" durumuyla eşleşir.
        expect(_seriesCard('b'), findsOneWidget);
        expect(_seriesCard('a'), findsNothing);
        expect(_seriesCard('c'), findsNothing);
      },
    );
  });

  group('sıralama kontrolü (webde CatalogFilterForm "Sırala" alanının karşılığı)', () {
    testWidgets(
      '"Son güncellenen" varsayılan seçilidir ve API sırasını DEĞİŞTİRMEZ '
      '(kritik: istemci tarafında yanlışlıkla bir varsayılan sıralama '
      'eklenmediğini kanıtlar)',
      (tester) async {
        usePhoneViewport(tester);
        // API cevabı KASITLI olarak ne rating ne de title'a göre sıralı
        // DEĞİL — web'in `ORDER BY is_featured DESC, updated_at DESC, title
        // COLLATE NOCASE` sırasını taklit eden, alfabetik de puana göre de
        // olmayan gelişigüzel bir sıra.
        final repository = _FakeCatalogRepository(
          () async => _catalogWith([
            _series('z-serisi', 'Z Serisi', rating: 3.0),
            _series('a-serisi', 'A Serisi', rating: 5.0),
            _series('m-serisi', 'M Serisi', rating: 1.0),
          ]),
        );

        await tester.pumpWidget(_wrap(catalogRepository: repository));
        await tester.pumpAndSettle();

        // `findsWidgets` (en az bir), `findsOneWidget` DEĞİL: `DropdownMenu`
        // kapalı alanın gösterdiği metne (bir `EditableText`) ek olarak,
        // genişlik ölçümü için görünmez bir `Text` kopyası da her zaman
        // tutar (bkz. [_dropdownOption] doc yorumu).
        expect(find.text('Son güncellenen'), findsWidgets);
        expect(
          _visibleSeriesOrder(tester),
          ['z-serisi', 'a-serisi', 'm-serisi'],
        );
      },
    );

    testWidgets('"Puana göre" seçmek rating\'e göre azalan sıralar', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final repository = _FakeCatalogRepository(
        () async => _catalogWith([
          _series('dusuk', 'Düşük Puanlı', rating: 2.0),
          _series('yuksek', 'Yüksek Puanlı', rating: 4.8),
          _series('orta', 'Orta Puanlı', rating: 3.5),
        ]),
      );

      await tester.pumpWidget(_wrap(catalogRepository: repository));
      await tester.pumpAndSettle();

      await _selectDropdownOption(tester, _sortDropdown, 'Puana göre');

      expect(
        _visibleSeriesOrder(tester),
        ['yuksek', 'orta', 'dusuk'],
      );
    });

    testWidgets(
      '"Puana göre" eşit rating\'lerde slug ile kararlı biçimde sıralar',
      (tester) async {
        usePhoneViewport(tester);
        final repository = _FakeCatalogRepository(
          () async => _catalogWith([
            _series('z-slug', 'Z Serisi', rating: 4.0),
            _series('a-slug', 'A Serisi', rating: 4.0),
          ]),
        );

        await tester.pumpWidget(_wrap(catalogRepository: repository));
        await tester.pumpAndSettle();

        await _selectDropdownOption(tester, _sortDropdown, 'Puana göre');

        expect(_visibleSeriesOrder(tester), ['a-slug', 'z-slug']);
      },
    );

    testWidgets(
      '"Ada göre" seçmek Türkçe'
      '-duyarlı normalize edilmiş başlığa göre artan sıralar',
      (tester) async {
        usePhoneViewport(tester);
        final repository = _FakeCatalogRepository(
          () async => _catalogWith([
            _series('cay', 'Çay Bahçesi'),
            _series('istanbul', 'İstanbul Geceleri'),
            _series('araba', 'Araba Yolu'),
          ]),
        );

        await tester.pumpWidget(_wrap(catalogRepository: repository));
        await tester.pumpAndSettle();

        await _selectDropdownOption(tester, _sortDropdown, 'Ada göre');

        // normalizeCatalogSearch: 'Araba Yolu' -> 'araba yolu',
        // 'Çay Bahçesi' -> 'cay bahcesi', 'İstanbul Geceleri' ->
        // 'istanbul geceleri' — alfabetik olarak araba < cay < istanbul.
        expect(
          _visibleSeriesOrder(tester),
          ['araba', 'cay', 'istanbul'],
        );
      },
    );

    testWidgets(
      'sıralama + tür + durum + arama filtreleriyle birlikte çalışır',
      (tester) async {
        usePhoneViewport(tester);
        final repository = _FakeCatalogRepository(
          () async => _catalogWith([
            _series(
              'a',
              'Gece Vardiyası',
              genres: const ['Gizem'],
              status: 'Tamamlandı',
              rating: 3.0,
            ),
            _series(
              'b',
              'Gece Treni',
              genres: const ['Gizem'],
              status: 'Tamamlandı',
              rating: 4.9,
            ),
            _series(
              'c',
              'Gece Yolu',
              genres: const ['Romantizm'],
              status: 'Tamamlandı',
              rating: 5.0,
            ),
          ]),
        );
        final discovery = _FakeDiscoveryRepository(
          () async => _discoveryGenres(const ['Gizem', 'Romantizm']),
        );

        await tester.pumpWidget(
          _wrap(catalogRepository: repository, discoveryRepository: discovery),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('catalog-search-field')),
          'gece',
        );
        await tester.pumpAndSettle();
        await _selectDropdownOption(tester, _genreDropdown, 'Gizem');
        await _selectDropdownOption(tester, _statusDropdown, 'Tamamlandı');
        await _selectDropdownOption(tester, _sortDropdown, 'Puana göre');

        // 'c' Romantizm türünde olduğu için filtrelenip ELENİR; kalan 'a'
        // ve 'b' arasında rating'e göre azalan sıralanır (b: 4.9 > a: 3.0).
        expect(_visibleSeriesOrder(tester), ['b', 'a']);
      },
    );
  });
}
