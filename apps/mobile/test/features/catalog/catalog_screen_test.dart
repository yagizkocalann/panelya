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
}) {
  return SeriesSummary(
    slug: slug,
    title: title,
    eyebrow: eyebrow,
    creator: creator,
    description: description,
    longDescription: 'Long description',
    status: 'Devam Ediyor',
    genres: genres,
    tone: PanelTone.mint,
    updatedAt: 'Bugün',
    rating: 4.5,
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
Finder _genreChip(String genre) =>
    find.byKey(ValueKey('catalog-genre-chip-$genre'));

Widget _wrap({
  required DiscoverRepository catalogRepository,
  DiscoveryRepository? discoveryRepository,
  String? initialGenre,
}) {
  final router = GoRouter(
    initialLocation: '/catalog',
    routes: [
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

  group('tür filtresi — GET /api/discovery genres alanından gelir', () {
    testWidgets(
      'genre chips come from discoveryResponse.genres, not a client-side '
      'aggregation of the full catalog',
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

        expect(_genreChip('all'), findsOneWidget);
        expect(_genreChip('Gizem'), findsOneWidget);
        expect(_genreChip('Romantizm'), findsOneWidget);
        // Kataloğun kendi "Dram" türü, discovery `genres`'te YOK ve chip
        // olarak da GÖRÜNMEMELİ — kaynak bilerek `discoveryResponse.genres`,
        // tam kataloğun istemci tarafı türetmesi değil (bkz.
        // `catalog_screen.dart` doc yorumu).
        expect(_genreChip('Dram'), findsNothing);
      },
    );

    testWidgets(
      'selecting a genre chip filters the visible series to that genre',
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

        await tester.tap(_genreChip('Romantizm'));
        await tester.pumpAndSettle();

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
}
