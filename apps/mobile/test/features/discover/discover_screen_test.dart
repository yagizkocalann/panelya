import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/app/theme/tokens.dart';
import 'package:panelya_mobile/app/theme/tone_gradients.dart';
import 'package:panelya_mobile/core/api/api_exception.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/discover/domain/discover_repository.dart';
import 'package:panelya_mobile/features/discover/presentation/discover_providers.dart';
import 'package:panelya_mobile/features/discover/presentation/discover_screen.dart';

class _FakeDiscoverRepository implements DiscoverRepository {
  _FakeDiscoverRepository(this._result);

  final Future<CatalogResponse> Function() _result;

  @override
  Future<CatalogResponse> fetchCatalog() => _result();
}

CatalogResponse _catalogWith(
  List<SeriesSummary> series, {
  String? featuredSlug,
}) {
  return CatalogResponse(
    schemaVersion: '1.0',
    featuredSlug: featuredSlug ?? (series.isEmpty ? null : series.first.slug),
    series: series,
  );
}

/// `SeriesSummary` üretilen (generated) DTO'sunun wire-faithful, düz
/// (flattened) şeklini kullanır — eski `SeriesSummaryContract.metadata`
/// sarmalayıcısı yoktur (bkz. docs/mobile-handoff.md Ortaklık kuralları #3).
SeriesSummary _series(
  String slug,
  String title, {
  List<String> genres = const ['Gizem'],
  bool? isNew,
  PanelTone tone = PanelTone.mint,
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
    tone: tone,
    updatedAt: 'Bugün',
    rating: 4.5,
    followers: '1 B',
    isNew: isNew,
    episodeCount: 1,
    latestEpisode: const Episode(
      slug: 'bolum-1',
      number: 1,
      title: 'Bölüm 1',
      publishedAt: '18 Temmuz 2026',
      readTime: '5 dk',
      panels: [
        StoryPanel(id: 'panel-1', scene: 'Sahne', tone: PanelTone.mint),
      ],
    ),
  );
}

Widget _wrap(DiscoverRepository repository) {
  return ProviderScope(
    overrides: [discoverRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      theme: buildAppTheme(),
      home: const DiscoverScreen(),
    ),
  );
}

/// Bir seri kartının kökü (`SeriesCard`'a `discover_screen.dart`'ta
/// verilen `ValueKey('series-card-<slug>')`).
Finder _seriesCard(String slug) => find.byKey(ValueKey('series-card-$slug'));

/// Bir tür filtre chip'inin kökü.
Finder _genreChip(String genre) => find.byKey(ValueKey('genre-chip-$genre'));

const _heroFinder = ValueKey('featured-hero');

void main() {
  /// Keşif ekranının hero + tür şeridi + ızgara dikey akışı gerçekçi bir
  /// telefon oranında anlamlıdır; varsayılan 800x600 masaüstü test tuvali
  /// gerçek bir cihazı temsil etmez. Testleri gerçekçi bir telefon
  /// boyutuna sabitler; yine de olası kaydırmaya karşı dayanıklı olmak
  /// için etkileşimlerden önce `tester.ensureVisible` kullanılır.
  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('shows a loading indicator while the catalog loads', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeDiscoverRepository(
      () => Future<CatalogResponse>.delayed(
        const Duration(seconds: 1),
        () => _catalogWith(const []),
      ),
    );

    await tester.pumpWidget(_wrap(repository));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // The fake repository's `Future.delayed` timer must resolve before the
    // test ends, otherwise flutter_test's teardown asserts on a pending timer.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('renders the featured hero and series grid once resolved', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeDiscoverRepository(
      () async => _catalogWith([
        _series('gece-vardiyasi', 'Gece Vardiyası', genres: const ['Gizem', 'Dram']),
        _series('yarinki-ses', 'Yarınki Ses', genres: const ['Romantizm']),
      ]),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    // Featured series (first in the list) renders as a distinct hero with
    // its own CTA, keyed separately from its (also present) grid card.
    expect(find.byKey(_heroFinder), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(_heroFinder), matching: find.text('Gece Vardiyası')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(_heroFinder), matching: find.text('Seriyi incele')),
      findsOneWidget,
    );

    // Genre filter chips are derived from every series' `genres` field.
    expect(_genreChip('all'), findsOneWidget);
    expect(_genreChip('Gizem'), findsOneWidget);
    expect(_genreChip('Dram'), findsOneWidget);
    expect(_genreChip('Romantizm'), findsOneWidget);

    // Both series appear as grid cards (mirrors the web home page, where
    // the featured/index-0 series also reappears in the card feed below
    // the hero — bkz. `app/page.tsx`).
    await tester.ensureVisible(_seriesCard('gece-vardiyasi'));
    await tester.ensureVisible(_seriesCard('yarinki-ses'));
    expect(_seriesCard('gece-vardiyasi'), findsOneWidget);
    expect(_seriesCard('yarinki-ses'), findsOneWidget);
    expect(
      find.descendant(
        of: _seriesCard('yarinki-ses'),
        matching: find.text('Yarınki Ses'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'a cover-less series card renders the tone poster gradient in its '
    'placeholder (mirrors app/globals.css .poster--<tone>)',
    (tester) async {
      usePhoneViewport(tester);
      final repository = _FakeDiscoverRepository(
        () async => _catalogWith([
          _series('gece-vardiyasi', 'Gece Vardiyası', tone: PanelTone.violet),
        ]),
      );

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      // `_series` never sets `coverImage`, so the card always renders the
      // `CoverImage` placeholder — no separate "no cover" fixture needed.
      final containerFinder = find.descendant(
        of: _seriesCard('gece-vardiyasi'),
        matching: find.byType(Container),
      );
      expect(containerFinder, findsOneWidget);
      final decoration =
          tester.widget<Container>(containerFinder).decoration as BoxDecoration;
      expect(decoration.gradient, posterGradientForTone(PanelTone.violet));
      expect(decoration.color, isNull);
    },
  );

  testWidgets(
    'a cover-less series card falls back to the flat surface3 color when '
    'the tone is PanelTone.unknown (no gradient mapping)',
    (tester) async {
      usePhoneViewport(tester);
      final repository = _FakeDiscoverRepository(
        () async => _catalogWith([
          _series('gece-vardiyasi', 'Gece Vardiyası', tone: PanelTone.unknown),
        ]),
      );

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      final containerFinder = find.descendant(
        of: _seriesCard('gece-vardiyasi'),
        matching: find.byType(Container),
      );
      expect(containerFinder, findsOneWidget);
      final decoration =
          tester.widget<Container>(containerFinder).decoration as BoxDecoration;
      expect(decoration.gradient, isNull);
      expect(decoration.color, AppTokens.dark.colors.surface3);
    },
  );

  testWidgets('filtering by genre hides the hero and non-matching cards', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeDiscoverRepository(
      () async => _catalogWith([
        _series('gece-vardiyasi', 'Gece Vardiyası', genres: const ['Gizem']),
        _series('yarinki-ses', 'Yarınki Ses', genres: const ['Romantizm']),
      ]),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.ensureVisible(_genreChip('Romantizm'));
    await tester.tap(_genreChip('Romantizm'));
    await tester.pumpAndSettle();

    // Selecting a genre hides the featured hero (web parity, bkz.
    // `app/page.tsx`'teki `!isFiltered` koşulu) and filters the grid down
    // to matching series only.
    expect(find.byKey(_heroFinder), findsNothing);
    expect(_seriesCard('yarinki-ses'), findsOneWidget);
    expect(_seriesCard('gece-vardiyasi'), findsNothing);

    // Tapping the same chip again clears the filter back to "Tümü" and
    // restores the hero.
    await tester.tap(_genreChip('Romantizm'));
    await tester.pumpAndSettle();
    expect(find.byKey(_heroFinder), findsOneWidget);
    expect(_seriesCard('gece-vardiyasi'), findsOneWidget);
  });

  testWidgets('shows the empty state when the catalog has no series', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeDiscoverRepository(
      () async => _catalogWith(const []),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Henüz yayınlanmış bir seri yok.'), findsOneWidget);
  });

  testWidgets('shows an error view with a working retry button', (
    tester,
  ) async {
    usePhoneViewport(tester);
    var attempt = 0;
    final repository = _FakeDiscoverRepository(() async {
      attempt += 1;
      if (attempt == 1) {
        throw const NetworkException('bağlantı yok');
      }
      return _catalogWith([_series('gece-vardiyasi', 'Gece Vardiyası')]);
    });

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(_seriesCard('gece-vardiyasi'), findsNothing);

    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();

    expect(find.byKey(_heroFinder), findsOneWidget);
    expect(_seriesCard('gece-vardiyasi'), findsOneWidget);
  });
}
