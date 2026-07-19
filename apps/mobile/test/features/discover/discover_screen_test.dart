import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/app/theme/tokens.dart';
import 'package:panelya_mobile/app/theme/tone_gradients.dart';
import 'package:panelya_mobile/core/api/api_exception.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/discover/domain/discover_repository.dart';
import 'package:panelya_mobile/features/discover/presentation/discover_providers.dart';
import 'package:panelya_mobile/features/discover/presentation/discover_screen.dart';
import 'package:panelya_mobile/features/progress/domain/reading_progress.dart';
import 'package:panelya_mobile/features/progress/domain/reading_progress_repository.dart';
import 'package:panelya_mobile/features/progress/presentation/reading_progress_providers.dart';
import 'package:panelya_mobile/shared/layout/content_max_width.dart';

import '../../support/overflow_watcher.dart';
import '../../support/viewports.dart';

class _FakeDiscoverRepository implements DiscoverRepository {
  _FakeDiscoverRepository(this._result);

  final Future<CatalogResponse> Function() _result;

  @override
  Future<CatalogResponse> fetchCatalog() => _result();
}

/// In-memory sahte ilerleme deposu (bkz. `series_screen_test.dart`'taki
/// eşdeğeri): keşif ekranındaki "Okumaya devam et" şeridinin varlığını/
/// yokluğunu, gerçek `SharedPreferences` deposuna dokunmadan test etmeyi
/// sağlar.
class _FakeReadingProgressRepository implements LocalReadingProgressRepository {
  _FakeReadingProgressRepository([Map<String, ReadingProgress>? seed])
    : _store = {...?seed};

  final Map<String, ReadingProgress> _store;

  @override
  ReadingProgress? findBySeries(String seriesSlug) => _store[seriesSlug];

  @override
  ReadingProgress? findMostRecent() {
    if (_store.isEmpty) return null;
    return _store.values.reduce(
      (a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b,
    );
  }

  @override
  Future<void> recordEpisodeOpened({
    required String seriesSlug,
    required String seriesTitle,
    required String episodeSlug,
    required int episodeNumber,
  }) async {
    _store[seriesSlug] = ReadingProgress(
      seriesSlug: seriesSlug,
      seriesTitle: seriesTitle,
      episodeSlug: episodeSlug,
      episodeNumber: episodeNumber,
      updatedAt: DateTime.now(),
      completed: false,
    );
  }

  @override
  Future<void> recordEpisodeCompleted({
    required String seriesSlug,
    required String seriesTitle,
    required String episodeSlug,
    required int episodeNumber,
    String? nextEpisodeSlug,
    int? nextEpisodeNumber,
  }) async {
    final hasNext = nextEpisodeSlug != null && nextEpisodeNumber != null;
    _store[seriesSlug] = ReadingProgress(
      seriesSlug: seriesSlug,
      seriesTitle: seriesTitle,
      episodeSlug: hasNext ? nextEpisodeSlug : episodeSlug,
      episodeNumber: hasNext ? nextEpisodeNumber : episodeNumber,
      updatedAt: DateTime.now(),
      completed: !hasNext,
    );
  }
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
      panels: [StoryPanel(id: 'panel-1', scene: 'Sahne', tone: PanelTone.mint)],
    ),
  );
}

Widget _wrap(
  DiscoverRepository repository, {
  LocalReadingProgressRepository? progressRepository,
  double? textScale,
}) {
  return ProviderScope(
    overrides: [
      discoverRepositoryProvider.overrideWithValue(repository),
      readingProgressRepositoryProvider.overrideWithValue(
        progressRepository ?? _FakeReadingProgressRepository(),
      ),
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      builder: textScale == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
      home: const DiscoverScreen(),
    ),
  );
}

/// `context.push` gerektiren şerit dokunuşunu test etmek için gerçek bir
/// go_router kurar; okuyucu rotası gerçek `ReaderScreen` yerine yalnız
/// hedef slug'ları görünür kılan bir işaretçi widget'tır (bkz.
/// `series_screen_test.dart`'taki aynı desen).
Widget _wrapWithRouter(
  DiscoverRepository repository, {
  LocalReadingProgressRepository? progressRepository,
  double? textScale,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const DiscoverScreen()),
      GoRoute(
        path: '/series/:slug/read/:episodeSlug',
        builder: (context, state) => Scaffold(
          body: Text(
            'READER:${state.pathParameters['slug']}/${state.pathParameters['episodeSlug']}',
          ),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      discoverRepositoryProvider.overrideWithValue(repository),
      readingProgressRepositoryProvider.overrideWithValue(
        progressRepository ?? _FakeReadingProgressRepository(),
      ),
    ],
    child: MaterialApp.router(
      theme: buildAppTheme(),
      routerConfig: router,
      builder: textScale == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
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
        _series(
          'gece-vardiyasi',
          'Gece Vardiyası',
          genres: const ['Gizem', 'Dram'],
        ),
        _series('yarinki-ses', 'Yarınki Ses', genres: const ['Romantizm']),
      ]),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    // Featured series (first in the list) renders as a distinct hero with
    // its own CTA, keyed separately from its (also present) grid card.
    expect(find.byKey(_heroFinder), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(_heroFinder),
        matching: find.text('Gece Vardiyası'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(_heroFinder),
        matching: find.text('Seriyi incele'),
      ),
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

  group('"Okumaya devam et" şeridi (cihaz-yerel kaldığın yerden devam et)', () {
    const continueStrip = ValueKey('continue-reading-strip');

    testWidgets(
      'with no local progress record, the strip is not rendered at all '
      '(ADR-010 — no empty state/placeholder)',
      (tester) async {
        usePhoneViewport(tester);
        final repository = _FakeDiscoverRepository(
          () async =>
              _catalogWith([_series('gece-vardiyasi', 'Gece Vardiyası')]),
        );

        await tester.pumpWidget(
          _wrap(
            repository,
            progressRepository: _FakeReadingProgressRepository(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(continueStrip), findsNothing);
      },
    );

    testWidgets(
      'with a local progress record, renders the strip below the hero and '
      'above the grid, showing the series title and episode number',
      (tester) async {
        usePhoneViewport(tester);
        final repository = _FakeDiscoverRepository(
          () async => _catalogWith([
            _series('gece-vardiyasi', 'Gece Vardiyası'),
            _series('yarinki-ses', 'Yarınki Ses'),
          ]),
        );
        final progressRepository = _FakeReadingProgressRepository({
          'gece-vardiyasi': ReadingProgress(
            seriesSlug: 'gece-vardiyasi',
            seriesTitle: 'Gece Vardiyası',
            episodeSlug: 'bolum-2',
            episodeNumber: 2,
            updatedAt: DateTime(2026, 7, 18),
            completed: false,
          ),
        });

        await tester.pumpWidget(
          _wrap(repository, progressRepository: progressRepository),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(continueStrip), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(continueStrip),
            matching: find.textContaining('Gece Vardiyası'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(continueStrip),
            matching: find.textContaining('Bölüm 2'),
          ),
          findsOneWidget,
        );

        // Sıra: hero -> devam-et şeridi -> ızgara (bkz. PLAN "keşif"
        // maddesi — hero'nun üstünde değil altında, ızgaradan önce).
        final heroBox = tester.getRect(find.byKey(_heroFinder));
        final stripBox = tester.getRect(find.byKey(continueStrip));
        final gridCardBox = tester.getRect(_seriesCard('gece-vardiyasi'));
        expect(stripBox.top, greaterThanOrEqualTo(heroBox.bottom));
        expect(gridCardBox.top, greaterThanOrEqualTo(stripBox.bottom));
      },
    );

    testWidgets('tapping the strip navigates to the recorded episode', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final repository = _FakeDiscoverRepository(
        () async => _catalogWith([_series('gece-vardiyasi', 'Gece Vardiyası')]),
      );
      final progressRepository = _FakeReadingProgressRepository({
        'gece-vardiyasi': ReadingProgress(
          seriesSlug: 'gece-vardiyasi',
          seriesTitle: 'Gece Vardiyası',
          episodeSlug: 'bolum-2',
          episodeNumber: 2,
          updatedAt: DateTime(2026, 7, 18),
          completed: false,
        ),
      });

      await tester.pumpWidget(
        _wrapWithRouter(repository, progressRepository: progressRepository),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(continueStrip));
      await tester.pumpAndSettle();

      expect(find.text('READER:gece-vardiyasi/bolum-2'), findsOneWidget);
    });
  });

  group('ızgara kolon sayısı genişliğe göre uyarlanır (PLAN Görev A.1)', () {
    test('telefon genişliğinde (360-430) 2 kolon korunur', () {
      expect(discoverGridColumnsForWidth(360), 2);
      expect(discoverGridColumnsForWidth(390), 2);
      expect(discoverGridColumnsForWidth(430), 2);
    });

    test('~768 tablet dikeyde 3-4 kolon aralığındadır', () {
      final columns = discoverGridColumnsForWidth(768);
      expect(columns, inInclusiveRange(3, 4));
    });

    test('~1024 tablet yatayda 4-5 kolon aralığındadır', () {
      final columns = discoverGridColumnsForWidth(1024);
      expect(columns, inInclusiveRange(4, 5));
    });

    test('genişlik arttıkça kolon sayısı asla azalmaz (monoton)', () {
      const widths = [360, 500, 600, 768, 900, 1024, 1200, 1440];
      var previous = 0;
      for (final width in widths) {
        final columns = discoverGridColumnsForWidth(width.toDouble());
        expect(columns, greaterThanOrEqualTo(previous));
        previous = columns;
      }
    });

    for (final entry in {
      'telefon dikey (390x844)': phonePortrait,
      'telefon yatay (844x390)': phoneLandscape,
      'tablet dikey (768x1024)': tabletPortrait,
      'tablet yatay (1024x768)': tabletLandscape,
    }.entries) {
      testWidgets(
        '${entry.key}: ızgara + hero + devam şeridi taşmadan render edilir',
        (tester) async {
          useViewport(tester, entry.value);
          final watcher = OverflowWatcher()..start();
          addTearDown(watcher.stop);

          final repository = _FakeDiscoverRepository(
            () async => _catalogWith([
              _series(
                'gece-vardiyasi',
                'Gece Vardiyası: Kayıp Dakikanın İzinde',
                genres: const ['Gizem', 'Dram', 'Bilim Kurgu'],
              ),
              _series(
                'yarinki-ses',
                'Yarınki Ses',
                genres: const ['Romantizm'],
              ),
              _series('son-teslimat', 'Son Teslimat', genres: const ['Gizem']),
              _series('kayip-adres', 'Kayıp Adres', genres: const ['Dram']),
              _series(
                'gece-yarisi',
                'Gece Yarısı Vardiyası',
                genres: const ['Aksiyon'],
              ),
            ]),
          );
          final progressRepository = _FakeReadingProgressRepository({
            'gece-vardiyasi': ReadingProgress(
              seriesSlug: 'gece-vardiyasi',
              seriesTitle: 'Gece Vardiyası',
              episodeSlug: 'bolum-2',
              episodeNumber: 2,
              updatedAt: DateTime(2026, 7, 18),
              completed: false,
            ),
          });

          await tester.pumpWidget(
            _wrap(repository, progressRepository: progressRepository),
          );
          await tester.pumpAndSettle();

          // Hero okuyucudakiyle tutarlı bir 760 px merkez sütunda kalır
          // (bkz. PLAN Görev A.1); ilk sliver olduğu için viewport
          // yüksekliğinden bağımsız her zaman mount edilir. "Okumaya devam
          // et" şeridi AYNI `CenteredMaxWidth` sarmalayıcısını kullanır
          // (bkz. `discover_screen.dart` ve ayrıca izole
          // `content_max_width_test.dart`); kısa (yatay telefon) viewport'ta
          // dev bir hero onu cache extent dışına itip hiç build
          // ETTİRMEYEBİLİR — bu yüzden burada yalnız zaten mount edilmişse
          // (best-effort) doğrulanır.
          final heroFinder = find.byKey(_heroFinder);
          final heroWidth = tester.getRect(heroFinder).width;
          expect(heroWidth, lessThanOrEqualTo(kContentMaxWidth));

          final stripFinder = find.byKey(
            const ValueKey('continue-reading-strip'),
          );
          if (stripFinder.evaluate().isNotEmpty) {
            final stripWidth = tester.getRect(stripFinder).width;
            expect(stripWidth, lessThanOrEqualTo(kContentMaxWidth));
          }

          expect(
            watcher.errors,
            isEmpty,
            reason: 'viewport=${entry.value}\n${watcher.describe()}',
          );
        },
      );
    }
  });

  group(
    'büyük yazı tipinde taşma yok (PLAN Görev B.1 — textScaler 1.3/1.6/2.0)',
    () {
      /// `FlutterError.onError`'ı sarıp bir RenderFlex/RenderBox taşması
      /// oluşup oluşmadığını yakalar (bkz. `OverflowWatcher` doc yorumu —
      /// taşmalar normalde throw edilmez, yalnız raporlanır).
      for (final scale in [1.3, 1.6, 2.0]) {
        for (final entry in {
          'telefon (390x844)': phonePortrait,
          'tablet dikey (768x1024)': tabletPortrait,
        }.entries) {
          testWidgets('keşif ekranı (hero + devam şeridi + ızgara + tür filtresi) '
              'scale=$scale, ${entry.key}', (tester) async {
            useViewport(tester, entry.value);
            final watcher = OverflowWatcher()..start();
            addTearDown(watcher.stop);

            final repository = _FakeDiscoverRepository(
              () async => _catalogWith([
                _series(
                  'gece-vardiyasi',
                  'Gece Vardiyası: Kayıp Dakikanın İzinde Bir Teslimat Hikâyesi',
                  genres: const ['Gizem', 'Dram', 'Bilim Kurgu', 'Aksiyon'],
                ),
                _series(
                  'yarinki-ses',
                  'Yarınki Ses',
                  genres: const ['Romantizm'],
                ),
                _series(
                  'son-teslimat',
                  'Son Teslimat',
                  genres: const ['Gizem'],
                ),
              ]),
            );
            final progressRepository = _FakeReadingProgressRepository({
              'gece-vardiyasi': ReadingProgress(
                seriesSlug: 'gece-vardiyasi',
                seriesTitle: 'Gece Vardiyası: Kayıp Dakikanın İzinde',
                episodeSlug: 'bolum-2',
                episodeNumber: 2,
                updatedAt: DateTime(2026, 7, 18),
                completed: false,
              ),
            });

            await tester.pumpWidget(
              _wrap(
                repository,
                progressRepository: progressRepository,
                textScale: scale,
              ),
            );
            await tester.pumpAndSettle();

            expect(
              watcher.errors,
              isEmpty,
              reason:
                  'scale=$scale, viewport=${entry.value}\n${watcher.describe()}',
            );
          });
        }

        testWidgets('boş durum (katalogda hiç seri yok) scale=$scale', (
          tester,
        ) async {
          useViewport(tester, phonePortrait);
          final watcher = OverflowWatcher()..start();
          addTearDown(watcher.stop);

          final repository = _FakeDiscoverRepository(
            () async => _catalogWith(const []),
          );

          await tester.pumpWidget(_wrap(repository, textScale: scale));
          await tester.pumpAndSettle();

          expect(watcher.errors, isEmpty, reason: watcher.describe());
        });

        testWidgets('hata durumu (yeniden dene butonuyla) scale=$scale', (
          tester,
        ) async {
          useViewport(tester, phonePortrait);
          final watcher = OverflowWatcher()..start();
          addTearDown(watcher.stop);

          final repository = _FakeDiscoverRepository(
            () async => throw const NetworkException('bağlantı yok'),
          );

          await tester.pumpWidget(_wrap(repository, textScale: scale));
          await tester.pumpAndSettle();

          // Erişilebilirlik dokunma hedefi: hata durumundaki "Tekrar dene"
          // butonu büyük yazı tipinde de en az 44 px yüksekliğinde kalır
          // (bkz. PLAN Görev B.3 — sabit `SizedBox(height: 44)` yerine tema
          // `minimumSize`'ı büyümeye izin verir, asla küçülmez).
          final buttonFinder = find.ancestor(
            of: find.text('Tekrar dene'),
            matching: find.byType(FilledButton),
          );
          final buttonSize = tester.getSize(buttonFinder);
          expect(buttonSize.height, greaterThanOrEqualTo(44));

          expect(watcher.errors, isEmpty, reason: watcher.describe());
        });
      }
    },
  );
}
