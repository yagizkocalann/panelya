import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/core/api/api_exception.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/discovery/domain/discovery_repository.dart';
import 'package:panelya_mobile/features/discovery/presentation/discovery_providers.dart';
import 'package:panelya_mobile/features/discovery/presentation/new_episodes_screen.dart';
import 'package:panelya_mobile/shared/widgets/episode_update_card.dart';

class _FakeDiscoveryRepository implements DiscoveryRepository {
  _FakeDiscoveryRepository(this._result);

  final Future<DiscoveryResponse> Function() _result;

  @override
  Future<DiscoveryResponse> fetchDiscovery() => _result();
}

DiscoverySeriesSummary _series(String slug, String title) {
  return DiscoverySeriesSummary(
    slug: slug,
    title: title,
    eyebrow: 'Eyebrow',
    creator: 'Panelya Originals',
    description: 'Description',
    longDescription: 'Long description',
    status: 'Devam Ediyor',
    genres: const ['Gizem'],
    tone: PanelTone.mint,
    updatedAt: 'Bugün',
    rating: 4.5,
    followers: '1 B',
    episodeCount: 1,
  );
}

EpisodeSummary _episode(String slug, int number, String title) {
  return EpisodeSummary(
    slug: slug,
    number: number,
    title: title,
    publishedAt: '18 Temmuz 2026',
    readTime: '5 dk',
    panelCount: 3,
  );
}

DiscoveryResponse _discoveryWith(List<DiscoveryEpisodeUpdate> updates) {
  return DiscoveryResponse(
    schemaVersion: '1.0',
    featuredSeries: null,
    featuredFirstEpisode: null,
    genres: const [],
    newSeries: const [],
    latestEpisodes: updates,
  );
}

Finder _episodeUpdate(String seriesSlug, String episodeSlug) =>
    find.byKey(ValueKey('episode-update-$seriesSlug-$episodeSlug'));

Widget _wrap(DiscoveryRepository repository) {
  final router = GoRouter(
    initialLocation: '/new-episodes',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/new-episodes',
        builder: (context, state) => const NewEpisodesScreen(),
      ),
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
        builder: (context, state) =>
            Scaffold(body: Text('SERIES:${state.pathParameters['slug']}')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [discoveryRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
  );
}

void main() {
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
        () => _discoveryWith(const []),
      ),
    );

    await tester.pumpWidget(_wrap(repository));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('shows an empty state when there are no episode updates', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeDiscoveryRepository(
      () async => _discoveryWith(const []),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Henüz yayınlanmış bir bölüm yok.'), findsOneWidget);
  });

  testWidgets('shows an error view with a working retry button', (
    tester,
  ) async {
    usePhoneViewport(tester);
    var attempt = 0;
    final repository = _FakeDiscoveryRepository(() async {
      attempt += 1;
      if (attempt == 1) throw const NetworkException('bağlantı yok');
      return _discoveryWith([
        DiscoveryEpisodeUpdate(
          series: _series('gece-vardiyasi', 'Gece Vardiyası'),
          episode: _episode('bolum-1', 1, 'İlk Bölüm'),
        ),
      ]);
    });

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Tekrar dene'), findsOneWidget);
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();

    expect(_episodeUpdate('gece-vardiyasi', 'bolum-1'), findsOneWidget);
  });

  testWidgets(
    'shows the FULL latestEpisodes list — no 4-card cap here (bkz. PLAN Görev 6)',
    (tester) async {
      usePhoneViewport(tester);
      final all = List.generate(
        7,
        (i) => DiscoveryEpisodeUpdate(
          series: _series('s$i', 'Seri $i'),
          episode: _episode('e$i', i + 1, 'Bölüm ${i + 1}'),
        ),
      );
      final repository = _FakeDiscoveryRepository(
        () async => _discoveryWith(all),
      );

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      expect(find.byType(EpisodeUpdateCard), findsNWidgets(7));
      for (var i = 0; i < 7; i++) {
        expect(_episodeUpdate('s$i', 'e$i'), findsOneWidget);
      }
    },
  );

  testWidgets('preserves the exact API order — never re-sorted client-side', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeDiscoveryRepository(
      () async => _discoveryWith([
        DiscoveryEpisodeUpdate(
          series: _series('zzz', 'ZZZ'),
          episode: _episode('e-zzz', 9, 'Son'),
        ),
        DiscoveryEpisodeUpdate(
          series: _series('aaa', 'AAA'),
          episode: _episode('e-aaa', 1, 'İlk'),
        ),
      ]),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    final cards = tester
        .widgetList<EpisodeUpdateCard>(find.byType(EpisodeUpdateCard))
        .toList();
    expect(cards.map((c) => c.series.slug).toList(), ['zzz', 'aaa']);
  });

  testWidgets('tapping an update opens the reader at that episode', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeDiscoveryRepository(
      () async => _discoveryWith([
        DiscoveryEpisodeUpdate(
          series: _series('gece-vardiyasi', 'Gece Vardiyası'),
          episode: _episode('bolum-3', 3, 'Üçüncü Bölüm'),
        ),
      ]),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.tap(_episodeUpdate('gece-vardiyasi', 'bolum-3'));
    await tester.pumpAndSettle();

    expect(find.text('READER:gece-vardiyasi/bolum-3'), findsOneWidget);
  });

  testWidgets('tapping "Seriyi incele" opens the series screen instead', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeDiscoveryRepository(
      () async => _discoveryWith([
        DiscoveryEpisodeUpdate(
          series: _series('gece-vardiyasi', 'Gece Vardiyası'),
          episode: _episode('bolum-3', 3, 'Üçüncü Bölüm'),
        ),
      ]),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Seriyi incele'));
    await tester.pumpAndSettle();

    expect(find.text('SERIES:gece-vardiyasi'), findsOneWidget);
  });

  testWidgets(
    'the app bar offers a home button that navigates to "/" and meets the '
    '44x44 touch target minimum (PLAN Görev 3)',
    (tester) async {
      usePhoneViewport(tester);
      final repository = _FakeDiscoveryRepository(
        () async => _discoveryWith(const []),
      );

      await tester.pumpWidget(_wrap(repository));
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
}
