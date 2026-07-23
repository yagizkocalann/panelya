import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/app/theme/tokens.dart';
import 'package:panelya_mobile/app/theme/tone_gradients.dart';
import 'package:panelya_mobile/core/api/api_exception.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/progress/domain/reading_progress.dart';
import 'package:panelya_mobile/features/progress/domain/reading_progress_repository.dart';
import 'package:panelya_mobile/features/progress/presentation/reading_progress_providers.dart';
import 'package:panelya_mobile/features/reader/domain/reader_repository.dart';
import 'package:panelya_mobile/features/reader/presentation/reader_providers.dart';
import 'package:panelya_mobile/features/reader/presentation/reader_screen.dart';
import 'package:panelya_mobile/shared/layout/content_max_width.dart';

import '../../support/overflow_watcher.dart';
import '../../support/viewports.dart';

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

/// In-memory sahte ilerleme deposu: gerçek implementasyonun upsert
/// mantığını (bkz. `SharedPreferencesReadingProgressRepository`) taklit
/// eder ki testler `recordEpisodeOpened`/`recordEpisodeCompleted`
/// çağrılarının hem yapıldığını hem de doğru veriyi taşıdığını
/// doğrulayabilsin.
class _FakeReadingProgressRepository implements LocalReadingProgressRepository {
  final List<String> openedCalls = [];
  final List<({String episodeSlug, String? nextEpisodeSlug})> completedCalls =
      [];
  final Map<String, ReadingProgress> _store = {};

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
    openedCalls.add('$seriesSlug/$episodeSlug');
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
    completedCalls.add((
      episodeSlug: episodeSlug,
      nextEpisodeSlug: nextEpisodeSlug,
    ));
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

/// `.invalid` bir RFC 2606 rezerve alan adıdır: DNS çözümü daima ve hızlı
/// biçimde başarısız olur, bu yüzden `Image.network` testlerde gerçek ağ
/// erişimine muhtaç kalmadan (ve asılı kalmadan) her zaman `errorBuilder`'a
/// düşer.
const _panelImageUrl = 'https://example.invalid/panel-1.png';

/// `packages/contracts/fixtures/episode-manifest.v1.json`'daki GERÇEK panel
/// `image.variants` değerlerini (bkz. görev bağlamı — "fixture'lardaki
/// gerçek varyant değerleriyle seçici entegrasyon testi") okuyup döner.
/// Fixture içeriği buraya elle kopyalanmaz; dosyadan okunup üretilen
/// `EpisodeManifestResponse.fromJson` ile ayrıştırılır (bkz.
/// `test/core/contracts/fixture_contracts_test.dart`'taki aynı desen).
/// `flutter test` her zaman paket kökünden (`apps/mobile`) çalıştırıldığı
/// için repo köküne göre relative yol `../../packages/contracts/fixtures`
/// olur.
List<PublicMediaVariant> _fixturePanelVariants() {
  final file = File('../../packages/contracts/fixtures/episode-manifest.v1.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final response = EpisodeManifestResponse.fromJson(json);
  return response.episode.panels.single.image!.variants!;
}

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
  double? textScale,
  LocalReadingProgressRepository? progressRepository,
}) {
  final needsBuilder = reduceMotion || textScale != null;
  return ProviderScope(
    overrides: [
      readerRepositoryProvider.overrideWithValue(repository),
      readingProgressRepositoryProvider.overrideWithValue(
        progressRepository ?? _FakeReadingProgressRepository(),
      ),
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      builder: needsBuilder
          ? (context, child) {
              var data = MediaQuery.of(context);
              if (reduceMotion) data = data.copyWith(disableAnimations: true);
              if (textScale != null) {
                data = data.copyWith(textScaler: TextScaler.linear(textScale));
              }
              return MediaQuery(data: data, child: child!);
            }
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
  LocalReadingProgressRepository? progressRepository,
}) {
  final router = GoRouter(
    initialLocation: '/series/$seriesSlug/read/$episodeSlug',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/series/:slug',
        // `canPop()` metinde taşınır ki testler gerçek `pop()` ile güvenli
        // `go()` düşüşünü ayırt edebilsin (bkz. "seriye dön" testleri):
        // yığında bu rotanın ALTINDA başka bir şey yoksa (bu helper'ın
        // `initialLocation`'ı zaten doğrudan okuyucu olduğu için) `false`
        // olur.
        builder: (context, state) => Scaffold(
          body: Text(
            'SERIES:${state.pathParameters['slug']} canPop=${context.canPop()}',
          ),
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
    overrides: [
      readerRepositoryProvider.overrideWithValue(repository),
      readingProgressRepositoryProvider.overrideWithValue(
        progressRepository ?? _FakeReadingProgressRepository(),
      ),
    ],
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

  testWidgets('separates a panel image from its text layer (ADR-016): caption/'
      'dialogue render outside the image semantics, scene stays label-only', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeReaderRepository(
      (seriesSlug, episodeSlug) async => _manifest(
        episodeSlug: episodeSlug,
        number: 1,
        panels: const [_panelWithText],
      ),
    );

    await tester.pumpWidget(
      _wrap(repository, seriesSlug: 'gece-vardiyasi', episodeSlug: 'bolum-1'),
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
    expect(find.text('Ece pencereden dışarı bakıyor'), findsNothing);

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
  });

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
        _wrap(repository, seriesSlug: 'gece-vardiyasi', episodeSlug: 'bolum-1'),
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

  testWidgets('renders the no-image fallback with the flat surface2 background '
      'when the panel tone is PanelTone.unknown (no gradient mapping)', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeReaderRepository(
      (seriesSlug, episodeSlug) async => _manifest(
        episodeSlug: episodeSlug,
        number: 1,
        panels: const [_panelWithoutImageUnknownTone],
      ),
    );

    await tester.pumpWidget(
      _wrap(repository, seriesSlug: 'gece-vardiyasi', episodeSlug: 'bolum-1'),
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
  });

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
        _wrap(repository, seriesSlug: 'gece-vardiyasi', episodeSlug: 'bolum-1'),
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

  testWidgets('tapping the previous/next icons in the app bar navigates with '
      'go_router, and the icon set updates to match the new episode', (
    tester,
  ) async {
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
  });

  testWidgets(
    'tapping "seriye dön" when the reader was reached directly (no back '
    'stack beneath it, e.g. a panelya:// deep link) falls back to a safe '
    'go() navigate to the series screen',
    (tester) async {
      usePhoneViewport(tester);
      final repository = _FakeReaderRepository(
        (seriesSlug, episodeSlug) async =>
            _manifest(episodeSlug: episodeSlug, number: 1),
      );

      // `_wrapWithRouter`'ın `initialLocation`'ı doğrudan okuyucu rotasıdır
      // (bkz. yukarıdaki tanım) — yığında ALTINDA hiçbir şey yok, yani
      // `canPop()` false. Bu, `_returnToSeries`'in `pop()` dalını DEĞİL,
      // güvenli `go()` düşüşünü tetiklemesi gereken senaryo.
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

      expect(
        find.text('SERIES:gece-vardiyasi canPop=false'),
        findsOneWidget,
      );
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

      // Burada da yığında altta hiçbir şey yok (bkz. `_wrapWithRouter`
      // `initialLocation`), bu yüzden aynı güvenli `go()` düşüşü devreye
      // girer (`canPop=false`) — bu bağlantı da `_SeriesReturnButton` ile
      // aynı `_returnToSeries` yardımcısını kullanır.
      expect(
        find.text('SERIES:gece-vardiyasi canPop=false'),
        findsOneWidget,
      );
    },
  );

  group('kök neden düzeltmesi (kullanıcı şikayeti: seri/bölüme girince geri '
      'dönülemiyor) — gerçek pop vs. güvenli go() vs. pushReplacement', () {
    /// Üç seviyeli GERÇEK bir yığın kurar: `/` (keşif işaretçisi) →
    /// `push('/series/:slug')` → `push('/series/:slug/read/:episodeSlug')`;
    /// yani `series_screen.dart`'taki gerçek `_EpisodeTile.onTap`
    /// (`context.push`) davranışını taklit eder. Seri işaretçisi kendi
    /// `context.canPop()` değerini metnine gömer ki testler `pop()` (yığının
    /// altını KORUR, `canPop=true` kalır) ile `go()` (yığını YENİDEN KURAR,
    /// `canPop=false` olur) arasındaki farkı doğrudan görebilsin.
    GoRouter buildStackedRouter(ReaderRepository repository) {
      return GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('DISCOVER')),
          ),
          GoRoute(
            path: '/series/:slug',
            builder: (context, state) => Scaffold(
              body: Text(
                'SERIES:${state.pathParameters['slug']} canPop=${context.canPop()}',
              ),
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
    }

    Widget wrapStackedRouter(GoRouter router, ReaderRepository repository) {
      return ProviderScope(
        overrides: [
          readerRepositoryProvider.overrideWithValue(repository),
          readingProgressRepositoryProvider.overrideWithValue(
            _FakeReadingProgressRepository(),
          ),
        ],
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      );
    }

    testWidgets(
      'reaching the reader via a real push chain (keşif → seri → okuyucu) '
      'then tapping "seriye dön" performs an ACTUAL pop: the series screen '
      'reappears and the discover screen underneath is still on the stack '
      '(canPop stays true) — the old context.go() behavior would have '
      'rebuilt the stack down to just the series route (canPop=false), '
      'losing the path back to discover',
      (tester) async {
        usePhoneViewport(tester);
        final repository = _FakeReaderRepository(
          (seriesSlug, episodeSlug) async =>
              _manifest(episodeSlug: episodeSlug, number: 1),
        );
        final router = buildStackedRouter(repository);

        await tester.pumpWidget(wrapStackedRouter(router, repository));
        await tester.pumpAndSettle();
        expect(find.text('DISCOVER'), findsOneWidget);

        router.push('/series/gece-vardiyasi');
        await tester.pumpAndSettle();
        router.push('/series/gece-vardiyasi/read/bolum-1');
        await tester.pumpAndSettle();
        expect(find.text('Bölüm 1'), findsOneWidget);

        await tester.tap(find.byTooltip('Seriye dön'));
        await tester.pumpAndSettle();

        expect(
          find.text('SERIES:gece-vardiyasi canPop=true'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'moving from episode 1 to episode 2 via the app bar "sonraki bölüm" '
      'icon uses pushReplacement: the episode page is SWAPPED, not stacked '
      'on top — tapping "seriye dön" from episode 2 afterwards pops straight '
      'to the series screen (not back to episode 1), and the stack below '
      'the reader (discover, then series) is preserved',
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
              );
            default:
              throw StateError('Beklenmeyen bölüm: $episodeSlug');
          }
        });
        final router = buildStackedRouter(repository);

        await tester.pumpWidget(wrapStackedRouter(router, repository));
        await tester.pumpAndSettle();

        router.push('/series/gece-vardiyasi');
        await tester.pumpAndSettle();
        router.push('/series/gece-vardiyasi/read/bolum-1');
        await tester.pumpAndSettle();
        expect(find.text('Bölüm 1'), findsOneWidget);

        await tester.tap(find.byTooltip('Sonraki bölüm: Bölüm 2'));
        await tester.pumpAndSettle();
        expect(find.text('Bölüm 2'), findsOneWidget);

        await tester.tap(find.byTooltip('Seriye dön'));
        await tester.pumpAndSettle();

        // Tek bir pop, doğrudan seri ekranına döner (bölüm 1'e DEĞİL) ve
        // altındaki keşif hâlâ oradadır — bölüm 1 sayfası yığında hiç
        // kalmamıştı (pushReplacement onu DEĞİŞTİRMİŞTİ).
        expect(
          find.text('SERIES:gece-vardiyasi canPop=true'),
          findsOneWidget,
        );
        expect(find.text('Bölüm 1'), findsNothing);
      },
    );
  });

  group('anasayfaya doğrudan dönüş (PLAN Görev 3)', () {
    testWidgets(
      'the reader app bar (loading/error chrome) offers a home button that '
      'navigates to "/" and meets the 44x44 touch target minimum',
      (tester) async {
        usePhoneViewport(tester);
        final repository = _FakeReaderRepository(
          (seriesSlug, episodeSlug) =>
              Completer<EpisodeManifestResponse>().future,
        );

        await tester.pumpWidget(
          _wrapWithRouter(
            repository,
            seriesSlug: 'gece-vardiyasi',
            episodeSlug: 'bolum-1',
          ),
        );
        await tester.pump();

        final homeButton = find.byTooltip('Ana sayfa');
        expect(homeButton, findsOneWidget);
        expect(tester.getSize(homeButton).width, greaterThanOrEqualTo(44));
        expect(tester.getSize(homeButton).height, greaterThanOrEqualTo(44));

        await tester.tap(homeButton);
        await tester.pumpAndSettle();

        expect(find.text('HOME'), findsOneWidget);
      },
    );

    testWidgets(
      'the reader app bar (success chrome) offers a home button that '
      'navigates to "/" and meets the 44x44 touch target minimum',
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

        final homeButton = find.byTooltip('Ana sayfa');
        expect(homeButton, findsOneWidget);
        expect(tester.getSize(homeButton).width, greaterThanOrEqualTo(44));
        expect(tester.getSize(homeButton).height, greaterThanOrEqualTo(44));

        await tester.tap(homeButton);
        await tester.pumpAndSettle();

        expect(find.text('HOME'), findsOneWidget);
      },
    );
  });

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
        _wrap(repository, seriesSlug: 'gece-vardiyasi', episodeSlug: 'bolum-1'),
      );
      await tester.pump();

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(animatedOpacity.duration, isNot(Duration.zero));

      await tester.pumpAndSettle();
    },
  );

  group('cihaz-yerel "kaldığın yerden devam et" kaydı', () {
    List<StoryPanel> tallPanels(int count) => List.generate(
      count,
      (i) => StoryPanel(
        id: 'panel-$i',
        scene: 'Sahne $i',
        tone: PanelTone.mint,
        image: StoryPanelImage(
          src: _panelImageUrl,
          alt: 'Panel $i',
          width: 800,
          height: 1200,
        ),
      ),
    );

    testWidgets('opening an episode immediately records it as the '
        'continue target for its series', (tester) async {
      usePhoneViewport(tester);
      final repository = _FakeReaderRepository(
        (seriesSlug, episodeSlug) async => _manifest(
          episodeSlug: episodeSlug,
          number: 2,
          seriesSlug: 'gece-vardiyasi',
          seriesTitle: 'Gece Vardiyası',
        ),
      );
      final progressRepository = _FakeReadingProgressRepository();

      await tester.pumpWidget(
        _wrap(
          repository,
          seriesSlug: 'gece-vardiyasi',
          episodeSlug: 'bolum-2',
          progressRepository: progressRepository,
        ),
      );
      await tester.pumpAndSettle();

      expect(progressRepository.openedCalls, ['gece-vardiyasi/bolum-2']);
      final stored = progressRepository.findBySeries('gece-vardiyasi');
      expect(stored, isNotNull);
      expect(stored!.episodeSlug, 'bolum-2');
      expect(stored.episodeNumber, 2);
      expect(stored.seriesTitle, 'Gece Vardiyası');
      expect(stored.completed, isFalse);
    });

    testWidgets(
      'scrolling to the end of an episode that has a next episode advances '
      'the continue target to that next episode',
      (tester) async {
        usePhoneViewport(tester);
        final repository = _FakeReaderRepository(
          (seriesSlug, episodeSlug) async => _manifest(
            episodeSlug: 'bolum-1',
            number: 1,
            panels: tallPanels(4),
            next: const EpisodeNavigationRef(slug: 'bolum-2', number: 2),
          ),
        );
        final progressRepository = _FakeReadingProgressRepository();

        await tester.pumpWidget(
          _wrap(
            repository,
            seriesSlug: 'gece-vardiyasi',
            episodeSlug: 'bolum-1',
            progressRepository: progressRepository,
          ),
        );
        await tester.pumpAndSettle();

        // Uzun (4 panelli) içerik viewport'a sığmadığından bu noktada
        // henüz "bitti" kaydı YOK; yalnız açılış kaydedildi.
        expect(progressRepository.completedCalls, isEmpty);

        await tester.fling(
          find.byType(Scrollable).first,
          const Offset(0, -20000),
          3000,
        );
        await tester.pumpAndSettle();

        expect(progressRepository.completedCalls, hasLength(1));
        expect(progressRepository.completedCalls.single.episodeSlug, 'bolum-1');
        expect(
          progressRepository.completedCalls.single.nextEpisodeSlug,
          'bolum-2',
        );

        final stored = progressRepository.findBySeries('gece-vardiyasi');
        expect(stored!.episodeSlug, 'bolum-2');
        expect(stored.episodeNumber, 2);
        expect(stored.completed, isFalse);
      },
    );

    testWidgets('scrolling to the end of the last episode (no next) marks the '
        'progress record completed, still pointing at that episode', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final repository = _FakeReaderRepository(
        (seriesSlug, episodeSlug) async =>
            _manifest(episodeSlug: 'bolum-3', number: 3, panels: tallPanels(4)),
      );
      final progressRepository = _FakeReadingProgressRepository();

      await tester.pumpWidget(
        _wrap(
          repository,
          seriesSlug: 'gece-vardiyasi',
          episodeSlug: 'bolum-3',
          progressRepository: progressRepository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, -20000),
        3000,
      );
      await tester.pumpAndSettle();

      final stored = progressRepository.findBySeries('gece-vardiyasi');
      expect(stored!.episodeSlug, 'bolum-3');
      expect(stored.episodeNumber, 3);
      expect(stored.completed, isTrue);
    });

    testWidgets('a short episode that already fits the viewport (no scrolling '
        'needed) is recorded as completed without any user scroll', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final repository = _FakeReaderRepository(
        (seriesSlug, episodeSlug) async => _manifest(
          episodeSlug: 'bolum-1',
          number: 1,
          panels: const [_panelWithoutImage],
        ),
      );
      final progressRepository = _FakeReadingProgressRepository();

      await tester.pumpWidget(
        _wrap(
          repository,
          seriesSlug: 'gece-vardiyasi',
          episodeSlug: 'bolum-1',
          progressRepository: progressRepository,
        ),
      );
      await tester.pumpAndSettle();

      expect(progressRepository.completedCalls, hasLength(1));
      final stored = progressRepository.findBySeries('gece-vardiyasi');
      expect(stored!.completed, isTrue);
    });
  });

  group('geniş ekranda/yatay yönelimde taşma yok (PLAN Görev A.3/A.4)', () {
    for (final entry in {
      'telefon yatay (844x390)': phoneLandscape,
      'tablet dikey (768x1024)': tabletPortrait,
      'tablet yatay (1024x768)': tabletLandscape,
    }.entries) {
      testWidgets(entry.key, (tester) async {
        useViewport(tester, entry.value);
        final watcher = OverflowWatcher()..start();
        addTearDown(watcher.stop);

        final repository = _FakeReaderRepository(
          (seriesSlug, episodeSlug) async => _manifest(
            episodeSlug: episodeSlug,
            number: 1,
            panels: const [_panelWithText, _panelWithoutImage],
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

        // Okuyucu içeriği 760 px merkez sütunda kalır (bkz. PLAN Görev
        // A.3 — mevcut davranış, `CenteredMaxWidth` ile paylaşılan sabite
        // taşındı); geniş ekranlarda tam genişliğe yayılmaz.
        final listBox = tester.getRect(find.byType(ListView));
        expect(listBox.width, lessThanOrEqualTo(kContentMaxWidth));

        expect(watcher.errors, isEmpty, reason: watcher.describe());
      });
    }
  });

  group(
    'büyük yazı tipinde taşma yok (PLAN Görev B.1 — textScaler 1.3/1.6/2.0)',
    () {
      for (final scale in [1.3, 1.6, 2.0]) {
        for (final entry in {
          'telefon (390x844)': phonePortrait,
          'tablet dikey (768x1024)': tabletPortrait,
        }.entries) {
          testWidgets('paneller (görsel + metin katmanı) + bölüm sonu gezinme '
              'scale=$scale, ${entry.key}', (tester) async {
            useViewport(tester, entry.value);
            final watcher = OverflowWatcher()..start();
            addTearDown(watcher.stop);

            final repository = _FakeReaderRepository(
              (seriesSlug, episodeSlug) async => _manifest(
                episodeSlug: episodeSlug,
                number: 1,
                title: 'Kayıp Dakikanın İzinde Uzun Bir Bölüm Başlığı Burada',
                panels: const [
                  _panelWithText,
                  _panelWithoutImage,
                  _panelWithoutImageUnknownTone,
                ],
                previous: const EpisodeNavigationRef(
                  slug: 'bolum-0',
                  number: 0,
                ),
                next: const EpisodeNavigationRef(slug: 'bolum-2', number: 2),
              ),
            );

            await tester.pumpWidget(
              _wrap(
                repository,
                seriesSlug: 'gece-vardiyasi',
                episodeSlug: 'bolum-1',
                textScale: scale,
              ),
            );
            await tester.pumpAndSettle();

            await _revealText(tester, 'Bu bölüm burada bitti.');

            expect(
              watcher.errors,
              isEmpty,
              reason:
                  'scale=$scale, viewport=${entry.value}\n${watcher.describe()}',
            );
          });
        }

        testWidgets('boş bölüm (panel yok) scale=$scale', (tester) async {
          useViewport(tester, phonePortrait);
          final watcher = OverflowWatcher()..start();
          addTearDown(watcher.stop);

          final repository = _FakeReaderRepository(
            (seriesSlug, episodeSlug) async => _manifest(
              episodeSlug: episodeSlug,
              number: 1,
              panels: const [],
            ),
          );

          await tester.pumpWidget(
            _wrap(
              repository,
              seriesSlug: 'gece-vardiyasi',
              episodeSlug: 'bolum-1',
              textScale: scale,
            ),
          );
          await tester.pumpAndSettle();

          expect(watcher.errors, isEmpty, reason: watcher.describe());
        });

        testWidgets('hata durumu (yeniden dene butonuyla) scale=$scale', (
          tester,
        ) async {
          useViewport(tester, phonePortrait);
          final watcher = OverflowWatcher()..start();
          addTearDown(watcher.stop);

          final repository = _FakeReaderRepository(
            (seriesSlug, episodeSlug) async =>
                throw const NetworkException('bağlantı yok'),
          );

          await tester.pumpWidget(
            _wrap(
              repository,
              seriesSlug: 'gece-vardiyasi',
              episodeSlug: 'bolum-1',
              textScale: scale,
            ),
          );
          await tester.pumpAndSettle();

          expect(watcher.errors, isEmpty, reason: watcher.describe());
        });
      }
    },
  );

  group(
    'panel görseli varyant seçimi (packages/contracts fixture entegrasyonu)',
    () {
      /// Panel görselinin nihai (mutlak) yüklenen URL'ini döner (bkz.
      /// `test/shared/widgets/cover_image_test.dart`'taki aynı desen —
      /// `Image.network` bir `NetworkImage(url)` üretir).
      String renderedPanelImageUrl(WidgetTester tester) {
        final image = tester.widget<Image>(find.byType(Image));
        return (image.image as NetworkImage).url;
      }

      testWidgets(
        'image.variants yoksa mevcut image.src davranışı birebir korunur '
        '(geri-düşüş yolu regresyonsuz — canlı yerel API henüz varyant '
        'döndürmüyor)',
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

          expect(renderedPanelImageUrl(tester), _panelImageUrl);
        },
      );

      testWidgets(
        'dar okuyucu kolonu (390px telefon) + DPR 1.0: hedefi karşılayan '
        'en küçük fixture varyantı (480) seçilir',
        (tester) async {
          usePhoneViewport(tester); // 390x844, DPR 1.0.
          final panel = StoryPanel(
            id: 'panel-1',
            scene: 'Ece pencereden dışarı bakıyor',
            tone: PanelTone.mint,
            image: StoryPanelImage(
              src: _panelImageUrl,
              alt: 'Ece pencereden dışarı bakıyor, yağmurlu bir gece',
              width: 1080,
              height: 1920,
              variants: _fixturePanelVariants(),
            ),
          );
          final repository = _FakeReaderRepository(
            (seriesSlug, episodeSlug) async => _manifest(
              episodeSlug: episodeSlug,
              number: 1,
              panels: [panel],
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

          // 390 mantıksal px × 1.0 DPR = 390px hedef; 480 yeterli ve en
          // küçüğü.
          expect(
            renderedPanelImageUrl(tester),
            'http://localhost:3000/api/media/fixture-panel-1?width=480',
          );
        },
      );

      testWidgets(
        'hiçbir fixture varyantı hedefi karşılamıyorsa (yüksek DPR) en '
        'büyük varyant (768) seçilir; AspectRatio ana image.width/height '
        'oranından gelmeye devam eder (varyant oranı farklı olsa bile '
        'zıplama olmaz)',
        (tester) async {
          // `tester.view.physicalSize` FİZİKSEL piksel cinsindendir; mantıksal
          // genişliği 390 sabit tutmak için DPR ile orantılı büyütülür
          // (mantıksal = fiziksel / DPR).
          const devicePixelRatio = 3.0;
          tester.view.physicalSize = const Size(390, 844) * devicePixelRatio;
          tester.view.devicePixelRatio = devicePixelRatio;
          addTearDown(tester.view.reset);

          final panel = StoryPanel(
            id: 'panel-1',
            scene: 'Ece pencereden dışarı bakıyor',
            tone: PanelTone.mint,
            image: StoryPanelImage(
              src: _panelImageUrl,
              alt: 'Ece pencereden dışarı bakıyor, yağmurlu bir gece',
              width: 1080,
              height: 1920,
              variants: _fixturePanelVariants(),
            ),
          );
          final repository = _FakeReaderRepository(
            (seriesSlug, episodeSlug) async => _manifest(
              episodeSlug: episodeSlug,
              number: 1,
              panels: [panel],
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

          // 390 × 3.0 = 1170px hedef; 480 ve 768 ikisi de yetersiz -> en
          // büyüğü (768) döner.
          expect(
            renderedPanelImageUrl(tester),
            'http://localhost:3000/api/media/fixture-panel-1?width=768',
          );

          // AspectRatio her zaman ana `image.width`/`image.height`'tan
          // (1080/1920) gelir — seçilen 768 genişlikli varyantın kendi
          // oranı (768/1365) biraz farklı olsa bile düzen zıplamaz.
          final aspectRatio = tester.widget<AspectRatio>(
            find.byType(AspectRatio),
          );
          expect(aspectRatio.aspectRatio, 1080 / 1920);
        },
      );
    },
  );
}
