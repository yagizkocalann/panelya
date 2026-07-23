import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/core/api/api_exception.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/discover/presentation/discover_screen.dart';
import 'package:panelya_mobile/features/discovery/domain/discovery_repository.dart';
import 'package:panelya_mobile/features/discovery/presentation/discovery_providers.dart';
import 'package:panelya_mobile/features/progress/domain/reading_progress.dart';
import 'package:panelya_mobile/features/progress/domain/reading_progress_repository.dart';
import 'package:panelya_mobile/features/progress/presentation/reading_progress_providers.dart';
import 'package:panelya_mobile/shared/widgets/episode_update_card.dart';
import 'package:panelya_mobile/shared/widgets/series_card.dart';

import '../../support/overflow_watcher.dart';
import '../../support/viewports.dart';

class _FakeDiscoveryRepository implements DiscoveryRepository {
  _FakeDiscoveryRepository(this._result);

  final Future<DiscoveryResponse> Function() _result;

  @override
  Future<DiscoveryResponse> fetchDiscovery() => _result();
}

/// In-memory sahte ilerleme deposu (bkz. `series_screen_test.dart`'taki
/// eşdeğeri).
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

DiscoverySeriesSummary _series(
  String slug,
  String title, {
  List<String> genres = const ['Gizem'],
  bool? isNew,
  PanelTone tone = PanelTone.mint,
}) {
  return DiscoverySeriesSummary(
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
  );
}

EpisodeSummary _episode(
  String slug,
  int number,
  String title, {
  String publishedAt = '18 Temmuz 2026',
}) {
  return EpisodeSummary(
    slug: slug,
    number: number,
    title: title,
    publishedAt: publishedAt,
    readTime: '5 dk',
    panelCount: 3,
  );
}

DiscoveryResponse _discoveryWith({
  DiscoverySeriesSummary? featuredSeries,
  EpisodeSummary? featuredFirstEpisode,
  List<String> genres = const [],
  List<DiscoverySeriesSummary> newSeries = const [],
  List<DiscoveryEpisodeUpdate> latestEpisodes = const [],
}) {
  return DiscoveryResponse(
    schemaVersion: '1.0',
    featuredSeries: featuredSeries,
    featuredFirstEpisode: featuredFirstEpisode,
    genres: genres,
    newSeries: newSeries,
    latestEpisodes: latestEpisodes,
  );
}

Widget _wrap(
  DiscoveryRepository repository, {
  LocalReadingProgressRepository? progressRepository,
  double? textScale,
}) {
  return ProviderScope(
    overrides: [
      discoveryRepositoryProvider.overrideWithValue(repository),
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

/// `context.push` gerektiren navigasyonları test etmek için gerçek bir
/// go_router kurar; hedef ekranlar gerçek widget'lar yerine yalnız hangi
/// slug'a/rotaya ulaşıldığını görünür kılan işaretçi widget'lardır (bkz.
/// `series_screen_test.dart`'taki aynı desen).
Widget _wrapWithRouter(
  DiscoveryRepository repository, {
  LocalReadingProgressRepository? progressRepository,
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
      GoRoute(
        path: '/series/:slug',
        builder: (context, state) => Scaffold(
          body: Text('SERIES:${state.pathParameters['slug']}'),
        ),
      ),
      GoRoute(
        path: '/new-series',
        builder: (context, state) =>
            const Scaffold(body: Text('NEW_SERIES_SCREEN')),
      ),
      GoRoute(
        path: '/new-episodes',
        builder: (context, state) =>
            const Scaffold(body: Text('NEW_EPISODES_SCREEN')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      discoveryRepositoryProvider.overrideWithValue(repository),
      readingProgressRepositoryProvider.overrideWithValue(
        progressRepository ?? _FakeReadingProgressRepository(),
      ),
    ],
    child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
  );
}

Finder _seriesCard(String slug) => find.byKey(ValueKey('series-card-$slug'));
Finder _episodeUpdate(String seriesSlug, String episodeSlug) =>
    find.byKey(ValueKey('episode-update-$seriesSlug-$episodeSlug'));

const _heroFinder = ValueKey('featured-hero');
const _continueStrip = ValueKey('continue-reading-strip');
const _genreToggle = ValueKey('genre-disclosure-toggle');
const _seeAllNewSeries = ValueKey('see-all-new-series');
const _seeAllNewEpisodes = ValueKey('see-all-new-episodes');

void main() {
  // Bilerek gerçekçi bir telefon YÜKSEKLİĞİNDEN çok daha uzun bir tuval:
  // ana sayfa artık beş bölüm barındırıyor (tür dizini + hero + devam et +
  // yeni seriler + yeni bölümler) ve `CustomScrollView`/`Sliver*` içerik
  // görünüm alanı + önbellek payının (`cacheExtent`) DIŞINDaki widget'ları
  // hiç İNŞA ETMEZ. Testlerin çoğu (sıra, 4-kart kısıtı, navigasyon)
  // gerçek bir kaydırmayı DEĞİL, içeriğin doğruluğunu doğruladığı için en
  // basit ve güvenilir yol, tüm bölümlerin TEK seferde inşa edilmesini
  // garanti eden uzun bir tuval kullanmaktır. Gerçek cihaz
  // yüksekliklerindeki taşma/kaydırma davranışı ayrı bir grupta (bkz.
  // aşağıdaki "genişlik/viewport" grubu) gerçek `phonePortrait`/
  // `tabletPortrait` boyutları + açık bir kaydırma adımıyla kapsanır.
  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('shows a loading indicator while discovery loads', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeDiscoveryRepository(
      () => Future<DiscoveryResponse>.delayed(
        const Duration(seconds: 1),
        () => _discoveryWith(),
      ),
    );

    await tester.pumpWidget(_wrap(repository));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('shows the empty state when discovery has nothing to show', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeDiscoveryRepository(() async => _discoveryWith());

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Henüz yayınlanmış bir seri yok.'), findsOneWidget);
  });

  testWidgets('shows an error view with a working retry button', (
    tester,
  ) async {
    usePhoneViewport(tester);
    var attempt = 0;
    final repository = _FakeDiscoveryRepository(() async {
      attempt += 1;
      if (attempt == 1) {
        throw const NetworkException('bağlantı yok');
      }
      return _discoveryWith(
        featuredSeries: _series('gece-vardiyasi', 'Gece Vardiyası'),
      );
    });

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(find.byKey(_heroFinder), findsNothing);

    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();

    expect(find.byKey(_heroFinder), findsOneWidget);
  });

  group('bölüm sırası TAM OLARAK: tür dizini, hero, devam et, yeni seriler, '
      'yeni bölümler (PLAN Görev 3)', () {
    testWidgets('all five sections render in the required top-to-bottom order', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final repository = _FakeDiscoveryRepository(
        () async => _discoveryWith(
          featuredSeries: _series('gece-vardiyasi', 'Gece Vardiyası'),
          featuredFirstEpisode: _episode('bolum-1', 1, 'İlk İşaret'),
          genres: const ['Gizem', 'Romantizm'],
          newSeries: [_series('yeni-seri', 'Yeni Seri')],
          latestEpisodes: [
            DiscoveryEpisodeUpdate(
              series: _series('baska-seri', 'Başka Seri'),
              episode: _episode('bolum-2', 2, 'İkinci Bölüm'),
            ),
          ],
        ),
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

      final genreTop = tester.getRect(find.byKey(_genreToggle)).top;
      final heroTop = tester.getRect(find.byKey(_heroFinder)).top;
      final stripTop = tester.getRect(find.byKey(_continueStrip)).top;
      final newSeriesHeaderTop = tester
          .getRect(find.byKey(_seeAllNewSeries))
          .top;
      final newEpisodesHeaderTop = tester
          .getRect(find.byKey(_seeAllNewEpisodes))
          .top;

      expect(genreTop, lessThan(heroTop));
      expect(heroTop, lessThanOrEqualTo(stripTop));
      expect(stripTop, lessThan(newSeriesHeaderTop));
      expect(newSeriesHeaderTop, lessThan(newEpisodesHeaderTop));
    });
  });

  group('Yeni Seriler bölümü — en fazla 4 kart + Tümünü Gör (PLAN Görev 3/6)', () {
    testWidgets('shows at most 4 series cards even when the API returns more', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final repository = _FakeDiscoveryRepository(
        () async => _discoveryWith(
          newSeries: [
            _series('s1', 'Seri 1'),
            _series('s2', 'Seri 2'),
            _series('s3', 'Seri 3'),
            _series('s4', 'Seri 4'),
            _series('s5', 'Seri 5'),
            _series('s6', 'Seri 6'),
          ],
        ),
      );

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      expect(find.byType(SeriesCard), findsNWidgets(4));
      expect(_seriesCard('s1'), findsOneWidget);
      expect(_seriesCard('s4'), findsOneWidget);
      expect(_seriesCard('s5'), findsNothing);
      expect(_seriesCard('s6'), findsNothing);
    });

    testWidgets('preserves the exact API order — never re-sorted client-side', (
      tester,
    ) async {
      usePhoneViewport(tester);
      // Kasıtlı olarak alfabetik/rating sırasının TERSİNDE: istemci hiçbir
      // yeniden sıralama yapmamalı (bkz. docs/mobile-handoff.md madde 5).
      final repository = _FakeDiscoveryRepository(
        () async => _discoveryWith(
          newSeries: [
            _series('zzz-series', 'ZZZ Serisi'),
            _series('aaa-series', 'AAA Serisi'),
            _series('mmm-series', 'MMM Serisi'),
          ],
        ),
      );

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      final cards = tester.widgetList<SeriesCard>(find.byType(SeriesCard)).toList();
      expect(cards.map((c) => c.series.slug).toList(), [
        'zzz-series',
        'aaa-series',
        'mmm-series',
      ]);
    });

    testWidgets('tapping "Tümünü Gör" navigates to /new-series', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final repository = _FakeDiscoveryRepository(
        () async => _discoveryWith(
          newSeries: [_series('yeni-seri', 'Yeni Seri')],
        ),
      );

      await tester.pumpWidget(_wrapWithRouter(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_seeAllNewSeries));
      await tester.pumpAndSettle();

      expect(find.text('NEW_SERIES_SCREEN'), findsOneWidget);
    });

    testWidgets('section is hidden entirely when there is no new series', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final repository = _FakeDiscoveryRepository(
        () async => _discoveryWith(
          featuredSeries: _series('gece-vardiyasi', 'Gece Vardiyası'),
        ),
      );

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      expect(find.byKey(_seeAllNewSeries), findsNothing);
    });
  });

  group(
    'Yeni Eklenen Bölümler bölümü — en fazla 4 kart + Tümünü Gör (PLAN Görev 3/6)',
    () {
      testWidgets('shows at most 4 episode updates even when the API returns more', (
        tester,
      ) async {
        usePhoneViewport(tester);
        final updates = List.generate(
          6,
          (i) => DiscoveryEpisodeUpdate(
            series: _series('s$i', 'Seri $i'),
            episode: _episode('e$i', i + 1, 'Bölüm ${i + 1}'),
          ),
        );
        final repository = _FakeDiscoveryRepository(
          () async => _discoveryWith(latestEpisodes: updates),
        );

        await tester.pumpWidget(_wrap(repository));
        await tester.pumpAndSettle();

        expect(find.byType(EpisodeUpdateCard), findsNWidgets(4));
        expect(_episodeUpdate('s0', 'e0'), findsOneWidget);
        expect(_episodeUpdate('s3', 'e3'), findsOneWidget);
        expect(_episodeUpdate('s4', 'e4'), findsNothing);
      });

      testWidgets('preserves the exact API order — never re-sorted client-side', (
        tester,
      ) async {
        usePhoneViewport(tester);
        final repository = _FakeDiscoveryRepository(
          () async => _discoveryWith(
            latestEpisodes: [
              DiscoveryEpisodeUpdate(
                series: _series('zzz', 'ZZZ'),
                episode: _episode('e-zzz', 9, 'Son'),
              ),
              DiscoveryEpisodeUpdate(
                series: _series('aaa', 'AAA'),
                episode: _episode('e-aaa', 1, 'İlk'),
              ),
            ],
          ),
        );

        await tester.pumpWidget(_wrap(repository));
        await tester.pumpAndSettle();

        final cards = tester
            .widgetList<EpisodeUpdateCard>(find.byType(EpisodeUpdateCard))
            .toList();
        expect(cards.map((c) => c.series.slug).toList(), ['zzz', 'aaa']);
      });

      testWidgets('tapping "Tümünü Gör" navigates to /new-episodes', (
        tester,
      ) async {
        usePhoneViewport(tester);
        final repository = _FakeDiscoveryRepository(
          () async => _discoveryWith(
            latestEpisodes: [
              DiscoveryEpisodeUpdate(
                series: _series('gece-vardiyasi', 'Gece Vardiyası'),
                episode: _episode('bolum-1', 1, 'İlk Bölüm'),
              ),
            ],
          ),
        );

        await tester.pumpWidget(_wrapWithRouter(repository));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_seeAllNewEpisodes));
        await tester.pumpAndSettle();

        expect(find.text('NEW_EPISODES_SCREEN'), findsOneWidget);
      });

      testWidgets('tapping an episode update opens the reader at that episode', (
        tester,
      ) async {
        usePhoneViewport(tester);
        final repository = _FakeDiscoveryRepository(
          () async => _discoveryWith(
            latestEpisodes: [
              DiscoveryEpisodeUpdate(
                series: _series('gece-vardiyasi', 'Gece Vardiyası'),
                episode: _episode('bolum-3', 3, 'Üçüncü Bölüm'),
              ),
            ],
          ),
        );

        await tester.pumpWidget(_wrapWithRouter(repository));
        await tester.pumpAndSettle();

        await tester.tap(_episodeUpdate('gece-vardiyasi', 'bolum-3'));
        await tester.pumpAndSettle();

        expect(find.text('READER:gece-vardiyasi/bolum-3'), findsOneWidget);
      });

      testWidgets('section is hidden entirely when there are no episode updates', (
        tester,
      ) async {
        usePhoneViewport(tester);
        final repository = _FakeDiscoveryRepository(
          () async => _discoveryWith(
            featuredSeries: _series('gece-vardiyasi', 'Gece Vardiyası'),
          ),
        );

        await tester.pumpWidget(_wrap(repository));
        await tester.pumpAndSettle();

        expect(find.byKey(_seeAllNewEpisodes), findsNothing);
      });
    },
  );

  group('Haftanın hikâyesi hero — ilk bölüm okuma aksiyonu (docs madde 3)', () {
    testWidgets(
      'shows both "İlk bölümü oku" and "Seriyi incele" when a first episode exists',
      (tester) async {
        usePhoneViewport(tester);
        final repository = _FakeDiscoveryRepository(
          () async => _discoveryWith(
            featuredSeries: _series('gece-vardiyasi', 'Gece Vardiyası'),
            featuredFirstEpisode: _episode('bolum-1', 1, 'İlk İşaret'),
          ),
        );

        await tester.pumpWidget(_wrapWithRouter(repository));
        await tester.pumpAndSettle();

        expect(find.text('İlk bölümü oku'), findsOneWidget);
        expect(find.text('Seriyi incele'), findsOneWidget);

        await tester.tap(find.text('İlk bölümü oku'));
        await tester.pumpAndSettle();
        expect(find.text('READER:gece-vardiyasi/bolum-1'), findsOneWidget);
      },
    );

    testWidgets(
      'shows only "Seriyi incele" when there is no first episode yet — no '
      'disabled/dead read button (ADR-010)',
      (tester) async {
        usePhoneViewport(tester);
        final repository = _FakeDiscoveryRepository(
          () async => _discoveryWith(
            featuredSeries: _series('gece-vardiyasi', 'Gece Vardiyası'),
          ),
        );

        await tester.pumpWidget(_wrapWithRouter(repository));
        await tester.pumpAndSettle();

        expect(find.text('İlk bölümü oku'), findsNothing);
        expect(find.text('Seriyi incele'), findsOneWidget);

        await tester.tap(find.text('Seriyi incele'));
        await tester.pumpAndSettle();
        expect(find.text('SERIES:gece-vardiyasi'), findsOneWidget);
      },
    );
  });

  group('"Okumaya devam et" şeridi (cihaz-yerel kaldığın yerden devam et)', () {
    testWidgets('with no local progress record, the strip is not rendered at all', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final repository = _FakeDiscoveryRepository(
        () async => _discoveryWith(
          featuredSeries: _series('gece-vardiyasi', 'Gece Vardiyası'),
        ),
      );

      await tester.pumpWidget(
        _wrap(repository, progressRepository: _FakeReadingProgressRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(_continueStrip), findsNothing);
    });

    testWidgets('tapping the strip navigates to the recorded episode', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final repository = _FakeDiscoveryRepository(
        () async => _discoveryWith(
          featuredSeries: _series('gece-vardiyasi', 'Gece Vardiyası'),
        ),
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

      await tester.tap(find.byKey(_continueStrip));
      await tester.pumpAndSettle();

      expect(find.text('READER:gece-vardiyasi/bolum-2'), findsOneWidget);
    });
  });

  group('genişlik/viewport ve büyük yazı tipinde taşma yok (PLAN Görev A/B.1)', () {
    for (final entry in {
      'telefon dikey (390x844)': phonePortrait,
      'tablet dikey (768x1024)': tabletPortrait,
    }.entries) {
      for (final scale in [1.0, 1.6, 2.0]) {
        testWidgets(
          'tüm bölümler (tür dizini + hero + devam et + yeni seriler + yeni '
          'bölümler) scale=$scale, ${entry.key}',
          (tester) async {
            useViewport(tester, entry.value);
            final watcher = OverflowWatcher()..start();
            addTearDown(watcher.stop);

            final repository = _FakeDiscoveryRepository(
              () async => _discoveryWith(
                featuredSeries: _series(
                  'gece-vardiyasi',
                  'Gece Vardiyası: Kayıp Dakikanın İzinde Bir Teslimat '
                      'Hikâyesi',
                  genres: const ['Gizem', 'Dram', 'Bilim Kurgu', 'Aksiyon'],
                ),
                featuredFirstEpisode: _episode('bolum-1', 1, 'İlk İşaret'),
                genres: const ['Gizem', 'Dram', 'Bilim Kurgu', 'Aksiyon'],
                newSeries: [
                  _series('yeni-seri-1', 'Yeni Seri Bir'),
                  _series('yeni-seri-2', 'Yeni Seri İki'),
                  _series('yeni-seri-3', 'Yeni Seri Üç'),
                ],
                latestEpisodes: [
                  DiscoveryEpisodeUpdate(
                    series: _series('baska-seri', 'Başka Seri'),
                    episode: _episode('bolum-2', 2, 'İkinci Bölüm'),
                  ),
                ],
              ),
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
              _wrap(
                repository,
                progressRepository: progressRepository,
                textScale: scale,
              ),
            );
            await tester.pumpAndSettle();

            // Gerçek cihaz yüksekliğinde beş bölümün tamamı ilk karede
            // görünür olmayabilir (bkz. `CustomScrollView`'ın lazy inşa
            // davranışı); alt bölümleri (Yeni Seriler/Yeni Eklenen
            // Bölümler) de aynı taşma taramasına dahil etmek için listenin
            // sonuna kadar kaydırılır.
            await tester.drag(
              find.byType(CustomScrollView),
              const Offset(0, -4000),
            );
            await tester.pumpAndSettle();

            expect(
              watcher.errors,
              isEmpty,
              reason:
                  'scale=$scale, viewport=${entry.value}\n${watcher.describe()}',
            );
          },
        );
      }
    }

    testWidgets('boş durum taşmadan render edilir', (tester) async {
      useViewport(tester, phonePortrait);
      final watcher = OverflowWatcher()..start();
      addTearDown(watcher.stop);

      final repository = _FakeDiscoveryRepository(() async => _discoveryWith());

      await tester.pumpWidget(_wrap(repository, textScale: 1.6));
      await tester.pumpAndSettle();

      expect(watcher.errors, isEmpty, reason: watcher.describe());
    });

    testWidgets(
      'hata durumu (yeniden dene butonuyla) taşmadan render edilir ve buton '
      'en az 44 px yükseklikte kalır',
      (tester) async {
        useViewport(tester, phonePortrait);
        final watcher = OverflowWatcher()..start();
        addTearDown(watcher.stop);

        final repository = _FakeDiscoveryRepository(
          () async => throw const NetworkException('bağlantı yok'),
        );

        await tester.pumpWidget(_wrap(repository, textScale: 1.6));
        await tester.pumpAndSettle();

        final buttonFinder = find.ancestor(
          of: find.text('Tekrar dene'),
          matching: find.byType(FilledButton),
        );
        final buttonSize = tester.getSize(buttonFinder);
        expect(buttonSize.height, greaterThanOrEqualTo(44));

        expect(watcher.errors, isEmpty, reason: watcher.describe());
      },
    );
  });
}
