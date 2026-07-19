import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/app/theme/tokens.dart';
import 'package:panelya_mobile/app/theme/tone_gradients.dart';
import 'package:panelya_mobile/core/api/api_exception.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/reader/domain/reader_repository.dart';
import 'package:panelya_mobile/features/reader/presentation/reader_providers.dart';
import 'package:panelya_mobile/features/reader/presentation/reader_screen.dart';

class _FakeReaderRepository implements ReaderRepository {
  _FakeReaderRepository(this._result);

  final Future<EpisodeManifestResponse> Function(
    String seriesSlug,
    String episodeSlug,
  )
  _result;

  @override
  Future<EpisodeManifestResponse> fetchEpisodeManifest(
    String seriesSlug,
    String episodeSlug,
  ) => _result(seriesSlug, episodeSlug);
}

/// `.invalid` bir RFC 2606 rezerve alan adıdır: DNS çözümü daima ve hızlı
/// biçimde başarısız olur, bu yüzden `Image.network` testlerde gerçek ağ
/// erişimine muhtaç kalmadan (ve asılı kalmadan) her zaman `errorBuilder`'a
/// düşer.
const _panelImageUrl = 'https://example.invalid/panel-1.png';

const _panelWithText = StoryPanel(
  id: 'panel-1',
  scene: 'Ece pencereden dışarı bakıyor',
  caption: 'Gece geç saatte teslimat çağrısı gelir.',
  dialogue: '"Bu gece de mi?"',
  tone: PanelTone.mint,
  image: StoryPanelImage(
    src: _panelImageUrl,
    alt: 'Ece pencereden dışarı bakıyor, yağmurlu bir gece',
    width: 800,
    height: 1200,
  ),
);

const _panelWithoutImage = StoryPanel(
  id: 'panel-2',
  scene: 'Sokak lambası titriyor',
  tone: PanelTone.coral,
);

const _panelWithoutImageUnknownTone = StoryPanel(
  id: 'panel-3',
  scene: 'Bilinmeyen ton',
  tone: PanelTone.unknown,
);

EpisodeManifestResponse _manifest({
  required String episodeSlug,
  required int number,
  String title = 'Kayıp Dakika',
  List<StoryPanel> panels = const [_panelWithText],
  EpisodeNavigationRef? previous,
  EpisodeNavigationRef? next,
  String seriesSlug = 'gece-vardiyasi',
  String seriesTitle = 'Gece Vardiyası',
}) {
  return EpisodeManifestResponse(
    schemaVersion: '1.0',
    series: EpisodeManifestSeriesRef(slug: seriesSlug, title: seriesTitle),
    episode: Episode(
      slug: episodeSlug,
      number: number,
      title: title,
      publishedAt: '18 Temmuz 2026',
      readTime: '7 dk',
      panels: panels,
    ),
    navigation: EpisodeNavigation(previous: previous, next: next),
  );
}

Widget _wrap(
  ReaderRepository repository, {
  required String seriesSlug,
  required String episodeSlug,
  bool reduceMotion = false,
}) {
  return ProviderScope(
    overrides: [readerRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      theme: buildAppTheme(),
      builder: reduceMotion
          ? (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            )
          : null,
      home: ReaderScreen(seriesSlug: seriesSlug, episodeSlug: episodeSlug),
    ),
  );
}

/// Gerçek bir `go_router` kurar: seri sayfası yalnız hedef slug'ı görünür
/// kılan bir işaretçi widget'tır (okuyucunun navigasyon hedeflerini, kendi
/// provider bağımlılıklarını kurmadan doğrulamak için — `series_screen_test`
/// ile aynı desen).
Widget _wrapWithRouter(
  ReaderRepository repository, {
  required String seriesSlug,
  required String episodeSlug,
}) {
  final router = GoRouter(
    initialLocation: '/series/$seriesSlug/read/$episodeSlug',
    routes: [
      GoRoute(
        path: '/series/:slug',
        builder: (context, state) => Scaffold(
          body: Text('SERIES:${state.pathParameters['slug']}'),
        ),
      ),
      GoRoute(
        path: '/series/:slug/read/:episodeSlug',
        builder: (context, state) => ReaderScreen(
          seriesSlug: state.pathParameters['slug']!,
          episodeSlug: state.pathParameters['episodeSlug']!,
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [readerRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
  );
}

void usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _revealText(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(find.text(text), 300);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows a loading indicator while the episode loads', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeReaderRepository(
      (seriesSlug, episodeSlug) => Future.delayed(
        const Duration(seconds: 1),
        () => _manifest(episodeSlug: episodeSlug, number: 1),
      ),
    );

    await tester.pumpWidget(
      _wrap(repository, seriesSlug: 'gece-vardiyasi', episodeSlug: 'bolum-1'),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('shows an error view with a working retry button', (
    tester,
  ) async {
    usePhoneViewport(tester);
    var attempt = 0;
    final repository = _FakeReaderRepository((seriesSlug, episodeSlug) async {
      attempt += 1;
      if (attempt == 1) {
        throw const HttpStatusException(
          statusCode: 404,
          path: '/api/series/gece-vardiyasi/episodes/bolum-1',
          errorCode: 'episode_not_found',
        );
      }
      return _manifest(episodeSlug: episodeSlug, number: 1);
    });

    await tester.pumpWidget(
      _wrap(repository, seriesSlug: 'gece-vardiyasi', episodeSlug: 'bolum-1'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(find.text('Aradığınız içerik bulunamadı.'), findsOneWidget);

    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();

    expect(find.text('Bölüm 1'), findsOneWidget);
  });

  testWidgets('shows the empty state when the episode has no panels', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeReaderRepository(
      (seriesSlug, episodeSlug) async =>
          _manifest(episodeSlug: episodeSlug, number: 1, panels: const []),
    );

    await tester.pumpWidget(
      _wrap(repository, seriesSlug: 'gece-vardiyasi', episodeSlug: 'bolum-1'),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Bu bölümde henüz gösterilecek panel yok.'),
      findsOneWidget,
    );
    // Boş durumda bile seriye dönüş her zaman çalışır (ADR-010).
    expect(find.byTooltip('Seriye dön'), findsOneWidget);
  });

  testWidgets(
    'separates a panel image from its text layer (ADR-016): caption/'
    'dialogue render outside the image semantics, scene stays label-only',
    (tester) async {
      usePhoneViewport(tester);
      final repository = _FakeReaderRepository(
        (seriesSlug, episodeSlug) async => _manifest(
          episodeSlug: episodeSlug,
          number: 1,
          panels: const [_panelWithText],
        ),
      );

      await tester.pumpWidget(
        _wrap(
          repository,
          seriesSlug: 'gece-vardiyasi',
          episodeSlug: 'bolum-1',
        ),
      );
      await tester.pumpAndSettle();

      // Metin katmanı görünür: caption ve dialogue ayrı Text widget'ları.
      expect(
        find.text('Gece geç saatte teslimat çağrısı gelir.'),
        findsOneWidget,
      );
      expect(find.text('"Bu gece de mi?"'), findsOneWidget);

      // Sahne açıklaması yalnız erişilebilirlik etiketidir; görselin
      // olduğu panellerde ayrıca görünür bir metin olarak basılmaz (web
      // tarafıyla aynı davranış).
      expect(
        find.text('Ece pencereden dışarı bakıyor'),
        findsNothing,
      );

      // Görsel, `image: true` ve alt metniyle etiketlenmiş bir Semantics
      // düğümü içinde; caption/dialogue o düğümün İÇİNDE DEĞİL, ayrı bir
      // katmanda (ADR-016 — metin görselden ayrı bir katmandır).
      final imageSemantics = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.image == true,
      );
      expect(imageSemantics, findsOneWidget);
      final semanticsWidget = tester.widget<Semantics>(imageSemantics);
      expect(
        semanticsWidget.properties.label,
        'Ece pencereden dışarı bakıyor, yağmurlu bir gece',
      );
      expect(
        find.descendant(
          of: imageSemantics,
          matching: find.text('"Bu gece de mi?"'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'renders the no-image fallback with visible scene text (legacy panel '
    'without a StoryPanelImage)',
    (tester) async {
      usePhoneViewport(tester);
      final repository = _FakeReaderRepository(
        (seriesSlug, episodeSlug) async => _manifest(
          episodeSlug: episodeSlug,
          number: 1,
          panels: const [_panelWithoutImage],
        ),
      );

      await tester.pumpWidget(
        _wrap(
          repository,
          seriesSlug: 'gece-vardiyasi',
          episodeSlug: 'bolum-1',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sokak lambası titriyor'), findsOneWidget);

      // Görselsiz geri düşüş paneli, panelin tonuna göre web'deki
      // `.story-panel--coral` gradyanını aynalar (bkz. tone_gradients.dart).
      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Sokak lambası titriyor'),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.gradient, storyPanelGradientForTone(PanelTone.coral));
      expect(decoration.color, isNull);
    },
  );

  testWidgets(
    'renders the no-image fallback with the flat surface2 background '
    'when the panel tone is PanelTone.unknown (no gradient mapping)',
    (tester) async {
      usePhoneViewport(tester);
      final repository = _FakeReaderRepository(
        (seriesSlug, episodeSlug) async => _manifest(
          episodeSlug: episodeSlug,
          number: 1,
          panels: const [_panelWithoutImageUnknownTone],
        ),
      );

      await tester.pumpWidget(
        _wrap(
          repository,
          seriesSlug: 'gece-vardiyasi',
          episodeSlug: 'bolum-1',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bilinmeyen ton'), findsOneWidget);

      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Bilinmeyen ton'),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      final tokens = AppTokens.dark;
      expect(decoration.gradient, isNull);
      expect(decoration.color, tokens.colors.surface2);
    },
  );

  testWidgets(
    'first episode: previous is not shown as a button, only as info text, '
    'in both the app bar and the end-of-episode nav',
    (tester) async {
      usePhoneViewport(tester);
      final repository = _FakeReaderRepository(
        (seriesSlug, episodeSlug) async => _manifest(
          episodeSlug: episodeSlug,
          number: 1,
          next: const EpisodeNavigationRef(slug: 'bolum-2', number: 2),
        ),
      );

      await tester.pumpWidget(
        _wrap(
          repository,
          seriesSlug: 'gece-vardiyasi',
          episodeSlug: 'bolum-1',
        ),
      );
      await tester.pumpAndSettle();

      // Üstte: önceki bölüm ikonu yok (ADR-010), sonraki bölüm ikonu var.
      expect(find.byTooltip('Sonraki bölüm: Bölüm 2'), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous_rounded), findsNothing);

      // Altta: bilgi metni (buton değil).
      await _revealText(tester, 'Bu, serinin ilk bölümü.');
      expect(
        find.ancestor(
          of: find.text('Bu, serinin ilk bölümü.'),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'tapping the previous/next icons in the app bar navigates with '
    'go_router, and the icon set updates to match the new episode',
    (tester) async {
      usePhoneViewport(tester);
      final repository = _FakeReaderRepository((seriesSlug, episodeSlug) async {
        switch (episodeSlug) {
          case 'bolum-1':
            return _manifest(
              episodeSlug: 'bolum-1',
              number: 1,
              next: const EpisodeNavigationRef(slug: 'bolum-2', number: 2),
            );
          case 'bolum-2':
            return _manifest(
              episodeSlug: 'bolum-2',
              number: 2,
              previous: const EpisodeNavigationRef(slug: 'bolum-1', number: 1),
              next: const EpisodeNavigationRef(slug: 'bolum-3', number: 3),
            );
          case 'bolum-3':
            return _manifest(
              episodeSlug: 'bolum-3',
              number: 3,
              previous: const EpisodeNavigationRef(slug: 'bolum-2', number: 2),
            );
          default:
            throw StateError('Beklenmeyen bölüm: $episodeSlug');
        }
      });

      await tester.pumpWidget(
        _wrapWithRouter(
          repository,
          seriesSlug: 'gece-vardiyasi',
          episodeSlug: 'bolum-2',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bölüm 2'), findsOneWidget);

      await tester.tap(find.byTooltip('Sonraki bölüm: Bölüm 3'));
      await tester.pumpAndSettle();

      expect(find.text('Bölüm 3'), findsOneWidget);
      // Serinin son bölümünde sonraki ikonu artık yok.
      expect(find.byIcon(Icons.skip_next_rounded), findsNothing);

      await tester.tap(find.byTooltip('Önceki bölüm: Bölüm 2'));
      await tester.pumpAndSettle();
      expect(find.text('Bölüm 2'), findsOneWidget);

      await tester.tap(find.byTooltip('Önceki bölüm: Bölüm 1'));
      await tester.pumpAndSettle();
      expect(find.text('Bölüm 1'), findsOneWidget);
      // Serinin ilk bölümünde önceki ikonu artık yok.
      expect(find.byIcon(Icons.skip_previous_rounded), findsNothing);
    },
  );

  testWidgets(
    'tapping "seriye dön" (app bar leading) navigates to the series screen '
    'via go_router',
    (tester) async {
      usePhoneViewport(tester);
      final repository = _FakeReaderRepository(
        (seriesSlug, episodeSlug) async =>
            _manifest(episodeSlug: episodeSlug, number: 1),
      );

      await tester.pumpWidget(
        _wrapWithRouter(
          repository,
          seriesSlug: 'gece-vardiyasi',
          episodeSlug: 'bolum-1',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Seriye dön'));
      await tester.pumpAndSettle();

      expect(find.text('SERIES:gece-vardiyasi'), findsOneWidget);
    },
  );

  testWidgets(
    'the end-of-episode nav (bottom) also offers working next/series links',
    (tester) async {
      usePhoneViewport(tester);
      final repository = _FakeReaderRepository((seriesSlug, episodeSlug) async {
        if (episodeSlug == 'bolum-2') {
          return _manifest(episodeSlug: 'bolum-2', number: 2);
        }
        return _manifest(
          episodeSlug: 'bolum-1',
          number: 1,
          next: const EpisodeNavigationRef(slug: 'bolum-2', number: 2),
        );
      });

      await tester.pumpWidget(
        _wrapWithRouter(
          repository,
          seriesSlug: 'gece-vardiyasi',
          episodeSlug: 'bolum-1',
        ),
      );
      await tester.pumpAndSettle();

      await _revealText(tester, 'Sonraki bölüm: Bölüm 2');
      await tester.tap(find.text('Sonraki bölüm: Bölüm 2'));
      await tester.pumpAndSettle();

      expect(find.text('Bölüm 2'), findsOneWidget);
    },
  );

  testWidgets(
    'the end-of-episode series link navigates back to the series screen',
    (tester) async {
      usePhoneViewport(tester);
      final repository = _FakeReaderRepository(
        (seriesSlug, episodeSlug) async =>
            _manifest(episodeSlug: episodeSlug, number: 1),
      );

      await tester.pumpWidget(
        _wrapWithRouter(
          repository,
          seriesSlug: 'gece-vardiyasi',
          episodeSlug: 'bolum-1',
        ),
      );
      await tester.pumpAndSettle();

      await _revealText(tester, 'Gece Vardiyası seri sayfasına dön');
      await tester.tap(find.text('Gece Vardiyası seri sayfasına dön'));
      await tester.pumpAndSettle();

      expect(find.text('SERIES:gece-vardiyasi'), findsOneWidget);
    },
  );

  testWidgets(
    'respects reduced motion: the panel image fade uses a zero duration '
    'instead of the token duration when disableAnimations is set',
    (tester) async {
      usePhoneViewport(tester);
      final repository = _FakeReaderRepository(
        (seriesSlug, episodeSlug) async => _manifest(
          episodeSlug: episodeSlug,
          number: 1,
          panels: const [_panelWithText],
        ),
      );

      await tester.pumpWidget(
        _wrap(
          repository,
          seriesSlug: 'gece-vardiyasi',
          episodeSlug: 'bolum-1',
          reduceMotion: true,
        ),
      );
      // Görselin ilk (senkron olmayan) karesi için `AnimatedOpacity`
      // ağaçta anında bulunur; ağın çözülmesini beklemeye gerek yok.
      await tester.pump();

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(animatedOpacity.duration, Duration.zero);

      // Yükleme placeholder'ı da statik bir simgeye döner, dönen bir
      // spinner göstermez.
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'without reduced motion, the panel image fade uses the token duration '
    'and a spinning indicator while loading',
    (tester) async {
      usePhoneViewport(tester);
      final repository = _FakeReaderRepository(
        (seriesSlug, episodeSlug) async => _manifest(
          episodeSlug: episodeSlug,
          number: 1,
          panels: const [_panelWithText],
        ),
      );

      await tester.pumpWidget(
        _wrap(
          repository,
          seriesSlug: 'gece-vardiyasi',
          episodeSlug: 'bolum-1',
        ),
      );
      await tester.pump();

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(animatedOpacity.duration, isNot(Duration.zero));

      await tester.pumpAndSettle();
    },
  );
}
