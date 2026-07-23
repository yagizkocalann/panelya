import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelya_mobile/app/router/route_args.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/catalog/presentation/catalog_screen.dart';
import 'package:panelya_mobile/features/discover/domain/discover_repository.dart';
import 'package:panelya_mobile/features/discover/presentation/discover_providers.dart';
import 'package:panelya_mobile/features/discovery/domain/discovery_repository.dart';
import 'package:panelya_mobile/features/discovery/presentation/discovery_providers.dart';
import 'package:panelya_mobile/features/discovery/presentation/genre_disclosure.dart';

const _toggleKey = ValueKey('genre-disclosure-toggle');
const _allSeriesChipKey = ValueKey('genre-disclosure-all-series-chip');

Finder _chip(String genre) => find.byKey(ValueKey('genre-disclosure-chip-$genre'));

/// Gerçek bir `go_router` kurar: `/` `GenreDisclosure`'ı gösterir, `/catalog`
/// ise yalnız aldığı `CatalogRouteArgs.initialGenre`'ı metin olarak gösteren
/// bir işaretçi ekrandır (bkz. `catalog_screen_test.dart`'taki aynı desen —
/// gerçek `CatalogScreen` yerine hedefi doğrulayan bir sahte).
Widget _wrap(List<String> genres) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            Scaffold(body: GenreDisclosure(genres: genres)),
      ),
      GoRoute(
        path: '/catalog',
        builder: (context, state) {
          final extra = state.extra;
          final initialGenre = extra is CatalogRouteArgs
              ? extra.initialGenre
              : null;
          return Scaffold(
            body: Text('CATALOG:${initialGenre ?? 'none'}'),
          );
        },
      ),
    ],
  );

  return MaterialApp.router(theme: buildAppTheme(), routerConfig: router);
}

void main() {
  testWidgets('renders nothing when the genre list is empty (ADR-010)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pumpAndSettle();

    expect(find.byKey(_toggleKey), findsNothing);
    expect(find.text('Türler'), findsNothing);
  });

  testWidgets(
    'starts closed: shows the down arrow and hides the genre chips',
    (tester) async {
      await tester.pumpWidget(_wrap(const ['Gizem', 'Romantizm']));
      await tester.pumpAndSettle();

      expect(find.text('Türler'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
      expect(_chip('Gizem'), findsNothing);
      expect(_chip('Romantizm'), findsNothing);
    },
  );

  testWidgets(
    'tapping the toggle opens it: arrow flips up and genre chips appear',
    (tester) async {
      await tester.pumpWidget(_wrap(const ['Gizem', 'Romantizm']));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_toggleKey));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
      expect(_chip('Gizem'), findsOneWidget);
      expect(_chip('Romantizm'), findsOneWidget);
    },
  );

  testWidgets(
    'the opened list always starts with "Tüm Seriler", before any genre '
    'chip (bkz. web app/components/GenreDirectoryLinks.tsx — filtresiz '
    '/catalog linki en başta gelir)',
    (tester) async {
      await tester.pumpWidget(_wrap(const ['Gizem', 'Romantizm']));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_toggleKey));
      await tester.pumpAndSettle();

      expect(find.byKey(_allSeriesChipKey), findsOneWidget);
      expect(find.text('Tüm Seriler'), findsOneWidget);

      // Wrap'in çocuk sırası görsel sırayla birebir aynıdır; ilk çocuğun
      // key'i "Tüm Seriler" olmalı, tür chip'leri ondan SONRA gelmeli.
      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.children.first.key, _allSeriesChipKey);
      expect(
        wrap.children.map((child) => child.key).toList(),
        [
          _allSeriesChipKey,
          const ValueKey('genre-disclosure-chip-Gizem'),
          const ValueKey('genre-disclosure-chip-Romantizm'),
        ],
      );
    },
  );

  testWidgets(
    'tapping "Tüm Seriler" has a real semantics label and navigates to '
    '/catalog with no genre extra (router falls back to initialGenre: '
    'null)',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const ['Gizem', 'Romantizm']));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_toggleKey));
      await tester.pumpAndSettle();

      final semantics =
          tester.getSemantics(find.byKey(_allSeriesChipKey)).getSemanticsData();
      expect(semantics.label, contains('Tüm serileri katalogda göster'));
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(semantics.hasAction(SemanticsAction.tap), isTrue);

      await tester.tap(find.byKey(_allSeriesChipKey));
      await tester.pumpAndSettle();

      expect(find.text('CATALOG:none'), findsOneWidget);

      handle.dispose();
    },
  );

  testWidgets('tapping the toggle again closes it back down', (tester) async {
    await tester.pumpWidget(_wrap(const ['Gizem']));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_toggleKey));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);

    await tester.tap(find.byKey(_toggleKey));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    expect(_chip('Gizem'), findsNothing);
  });

  testWidgets(
    'selecting a genre navigates to /catalog with that genre pre-selected '
    '(CatalogRouteArgs.initialGenre)',
    (tester) async {
      await tester.pumpWidget(_wrap(const ['Gizem', 'Romantizm']));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_toggleKey));
      await tester.pumpAndSettle();

      await tester.tap(_chip('Romantizm'));
      await tester.pumpAndSettle();

      expect(find.text('CATALOG:Romantizm'), findsOneWidget);
    },
  );

  group(
    '"Tüm Seriler" -> gerçek CatalogScreen ile uçtan uca (kullanıcı '
    'şikayeti: webde tüm serilere ulaşılabiliyor ama mobilde ulaşılamıyordu)',
    () {
      testWidgets(
        'GenreDisclosure açılıp "Tüm Seriler"e dokununca gerçek CatalogScreen '
        'FİLTRESİZ açılır: her iki türden de seri görünür ve kataloğun kendi '
        '"Tümü" chip\'i seçili olur',
        (tester) async {
          tester.view.physicalSize = const Size(390, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          final semanticsHandle = tester.ensureSemantics();

          final catalogRepository = _FakeCatalogRepository(
            () async => _catalogWith([
              _series('gece-vardiyasi', 'Gece Vardiyası', genres: const ['Gizem']),
              _series('yarinki-ses', 'Yarınki Ses', genres: const ['Romantizm']),
            ]),
          );
          final discoveryRepository = _FakeDiscoveryRepository(
            () async => _discoveryGenres(const ['Gizem', 'Romantizm']),
          );

          final router = GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => Scaffold(
                  body: GenreDisclosure(
                    genres: const ['Gizem', 'Romantizm'],
                  ),
                ),
              ),
              GoRoute(
                path: '/catalog',
                builder: (context, state) {
                  final extra = state.extra;
                  final initialGenre =
                      extra is CatalogRouteArgs ? extra.initialGenre : null;
                  return CatalogScreen(initialGenre: initialGenre);
                },
              ),
            ],
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                discoverRepositoryProvider.overrideWithValue(
                  catalogRepository,
                ),
                discoveryRepositoryProvider.overrideWithValue(
                  discoveryRepository,
                ),
              ],
              child: MaterialApp.router(
                theme: buildAppTheme(),
                routerConfig: router,
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(_toggleKey));
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(_allSeriesChipKey));
          await tester.pumpAndSettle();

          // Gerçek CatalogScreen açıldı (sahte işaretçi ekran değil) ve
          // her iki türden de seri görünüyor — hiçbir tür filtresi
          // uygulanmamış (eski/yeni ayrımı olmaksızın TÜM seriler).
          expect(find.text('Katalog'), findsOneWidget);
          expect(find.byKey(const ValueKey('series-card-gece-vardiyasi')),
              findsOneWidget);
          expect(find.byKey(const ValueKey('series-card-yarinki-ses')),
              findsOneWidget);

          final allChipSemantics = tester
              .getSemantics(find.byKey(const ValueKey('catalog-genre-chip-all')))
              .getSemanticsData();
          expect(allChipSemantics.flagsCollection.isSelected, Tristate.isTrue);

          semanticsHandle.dispose();
        },
      );
    },
  );
}

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
}) {
  return SeriesSummary(
    slug: slug,
    title: title,
    eyebrow: 'Eyebrow',
    creator: 'Panelya Originals',
    description: 'Description',
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
