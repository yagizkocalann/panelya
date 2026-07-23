import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/app/theme/tokens.dart';
import 'package:panelya_mobile/app/theme/tone_gradients.dart';
import 'package:panelya_mobile/core/api/api_exception.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/discovery/domain/discovery_repository.dart';
import 'package:panelya_mobile/features/discovery/presentation/discovery_providers.dart';
import 'package:panelya_mobile/features/discovery/presentation/new_series_screen.dart';
import 'package:panelya_mobile/shared/widgets/series_card.dart';

class _FakeDiscoveryRepository implements DiscoveryRepository {
  _FakeDiscoveryRepository(this._result);

  final Future<DiscoveryResponse> Function() _result;

  @override
  Future<DiscoveryResponse> fetchDiscovery() => _result();
}

DiscoverySeriesSummary _series(
  String slug,
  String title, {
  PanelTone tone = PanelTone.mint,
  bool? isNew = true,
}) {
  return DiscoverySeriesSummary(
    slug: slug,
    title: title,
    eyebrow: 'Eyebrow',
    creator: 'Panelya Originals',
    description: 'Description',
    longDescription: 'Long description',
    status: 'Devam Ediyor',
    genres: const ['Gizem'],
    tone: tone,
    updatedAt: 'Bugün',
    rating: 4.5,
    followers: '1 B',
    isNew: isNew,
    episodeCount: 1,
  );
}

DiscoveryResponse _discoveryWith(List<DiscoverySeriesSummary> newSeries) {
  return DiscoveryResponse(
    schemaVersion: '1.0',
    featuredSeries: null,
    featuredFirstEpisode: null,
    genres: const [],
    newSeries: newSeries,
    latestEpisodes: const [],
  );
}

Finder _seriesCard(String slug) => find.byKey(ValueKey('series-card-$slug'));

Widget _wrap(DiscoveryRepository repository) {
  final router = GoRouter(
    initialLocation: '/new-series',
    routes: [
      GoRoute(
        path: '/new-series',
        builder: (context, state) => const NewSeriesScreen(),
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

  testWidgets('shows an empty state when there is no new series', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeDiscoveryRepository(
      () async => _discoveryWith(const []),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Şu anda yeni bir seri yok.'), findsOneWidget);
  });

  testWidgets('shows an error view with a working retry button', (
    tester,
  ) async {
    usePhoneViewport(tester);
    var attempt = 0;
    final repository = _FakeDiscoveryRepository(() async {
      attempt += 1;
      if (attempt == 1) throw const NetworkException('bağlantı yok');
      return _discoveryWith([_series('yeni-seri', 'Yeni Seri')]);
    });

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Tekrar dene'), findsOneWidget);
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();

    expect(_seriesCard('yeni-seri'), findsOneWidget);
  });

  testWidgets(
    'shows the FULL newSeries list — no 4-card cap here (bkz. PLAN Görev 6)',
    (tester) async {
      usePhoneViewport(tester);
      final all = List.generate(7, (i) => _series('s$i', 'Seri $i'));
      final repository = _FakeDiscoveryRepository(
        () async => _discoveryWith(all),
      );

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      expect(find.byType(SeriesCard), findsNWidgets(7));
      for (var i = 0; i < 7; i++) {
        expect(_seriesCard('s$i'), findsOneWidget);
      }
    },
  );

  testWidgets('preserves the exact API order — never re-sorted client-side', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeDiscoveryRepository(
      () async => _discoveryWith([
        _series('zzz-series', 'ZZZ Serisi'),
        _series('aaa-series', 'AAA Serisi'),
        _series('mmm-series', 'MMM Serisi'),
      ]),
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

  testWidgets('tapping a card navigates to its series screen', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeDiscoveryRepository(
      () async => _discoveryWith([_series('gece-vardiyasi', 'Gece Vardiyası')]),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.tap(_seriesCard('gece-vardiyasi'));
    await tester.pumpAndSettle();

    expect(find.text('SERIES:gece-vardiyasi'), findsOneWidget);
  });

  group(
    'kapaksız kart tona göre poster gradyanı gösterir (mirrors '
    'app/globals.css .poster--<tone>; bkz. eski discover_screen_test.dart)',
    () {
      testWidgets('a cover-less series card renders the tone poster gradient', (
        tester,
      ) async {
        usePhoneViewport(tester);
        final repository = _FakeDiscoveryRepository(
          () async => _discoveryWith([
            _series(
              'gece-vardiyasi',
              'Gece Vardiyası',
              tone: PanelTone.violet,
              isNew: null,
            ),
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
        expect(decoration.gradient, posterGradientForTone(PanelTone.violet));
        expect(decoration.color, isNull);
      });

      testWidgets(
        'falls back to the flat surface3 color when the tone is unknown',
        (tester) async {
          usePhoneViewport(tester);
          final repository = _FakeDiscoveryRepository(
            () async => _discoveryWith([
              _series(
                'gece-vardiyasi',
                'Gece Vardiyası',
                tone: PanelTone.unknown,
                isNew: null,
              ),
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
    },
  );
}
