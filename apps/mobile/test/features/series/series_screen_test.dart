import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/core/api/api_exception.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/progress/domain/reading_progress.dart';
import 'package:panelya_mobile/features/progress/domain/reading_progress_repository.dart';
import 'package:panelya_mobile/features/progress/presentation/reading_progress_providers.dart';
import 'package:panelya_mobile/features/series/domain/series_repository.dart';
import 'package:panelya_mobile/features/series/presentation/series_providers.dart';
import 'package:panelya_mobile/features/series/presentation/series_screen.dart';

class _FakeSeriesRepository implements SeriesRepository {
  _FakeSeriesRepository(this._result);

  final Future<SeriesDetailResponse> Function(String slug) _result;

  @override
  Future<SeriesDetailResponse> fetchSeriesDetail(String slug) => _result(slug);
}

/// In-memory sahte ilerleme deposu (bkz. `reader_screen_test.dart`'taki
/// eşdeğeri): seri detay ekranının "Devam et" / "Baştan başla" kararını,
/// gerçek `SharedPreferences` deposuna dokunmadan test etmeyi sağlar.
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

SeriesMetadata _metadata({
  String slug = 'gece-vardiyasi',
  String status = 'Devam Ediyor',
}) {
  return SeriesMetadata(
    slug: slug,
    title: 'Gece Vardiyası',
    eyebrow: 'Zamanı geri saran bir teslimat',
    creator: 'Panelya Originals',
    description: 'Description',
    longDescription: 'Ece için gece vardiyası uzun bir açıklamadır.',
    status: status,
    genres: const ['Gizem', 'Bilim Kurgu'],
    tone: PanelTone.coral,
    updatedAt: 'Bugün',
    rating: 4.9,
    followers: '12,8 B',
  );
}

/// Sunucu bölümleri yeni-en eski sıralı döner (bkz.
/// `lib/core/contracts/generated/series_detail_response.dart`): burada da
/// aynı sırayla (bolum-3, bolum-2, bolum-1) kuruluyor ki "Okumaya başla"nın
/// gerçekten en düşük `number`'a (bolum-1) gittiği, listenin ilk öğesine
/// değil, doğrulanabilsin.
List<EpisodeSummary> _episodesNewestFirst() => const [
  EpisodeSummary(
    slug: 'bolum-3',
    number: 3,
    title: 'Kayıp Dakika',
    publishedAt: '18 Temmuz 2026',
    readTime: '7 dk',
    panelCount: 2,
  ),
  EpisodeSummary(
    slug: 'bolum-2',
    number: 2,
    title: 'Yarınki Adres',
    publishedAt: '12 Temmuz 2026',
    readTime: '8 dk',
    panelCount: 2,
  ),
  EpisodeSummary(
    slug: 'bolum-1',
    number: 1,
    title: 'Son Teslimat',
    publishedAt: '5 Temmuz 2026',
    readTime: '9 dk',
    panelCount: 7,
  ),
];

Widget _wrap(
  SeriesRepository repository, {
  required String slug,
  LocalReadingProgressRepository? progressRepository,
}) {
  return ProviderScope(
    overrides: [
      seriesRepositoryProvider.overrideWithValue(repository),
      readingProgressRepositoryProvider.overrideWithValue(
        progressRepository ?? _FakeReadingProgressRepository(),
      ),
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      home: SeriesScreen(slug: slug),
    ),
  );
}

/// `context.push` gerektiren "Okumaya başla" / bölüm dokunuşlarını test
/// etmek için gerçek bir go_router kurar; okuyucu rotası gerçek
/// `ReaderScreen` yerine yalnız hedef slug'ları görünür kılan bir işaretçi
/// widget'tır (okuyucunun kendi provider bağımlılıklarını kurmadan, salt
/// navigasyon hedefini doğrulamak için).
Widget _wrapWithRouter(
  SeriesRepository repository, {
  required String slug,
  LocalReadingProgressRepository? progressRepository,
}) {
  final router = GoRouter(
    initialLocation: '/series/$slug',
    routes: [
      GoRoute(
        path: '/series/:slug',
        builder: (context, state) =>
            SeriesScreen(slug: state.pathParameters['slug']!),
      ),
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
      seriesRepositoryProvider.overrideWithValue(repository),
      readingProgressRepositoryProvider.overrideWithValue(
        progressRepository ?? _FakeReadingProgressRepository(),
      ),
    ],
    child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
  );
}

/// Seri detay ekranı kapak + uzun açıklama + bölüm listesi içeren tek bir
/// dikey `ListView`; gerçekçi bir telefon viewport'unda bile içerik tek
/// ekrana sığmayabilir. Sliver tabanlı listeler viewport dışındaki
/// çocukları hiç build etmez, bu yüzden aşağıdaki öğeleri kontrol etmeden
/// önce sırayla görünür hale getirmek gerekir.
void usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _revealText(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(find.text(text), 200);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows a loading indicator while the series loads', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeSeriesRepository(
      (slug) => Future.delayed(
        const Duration(seconds: 1),
        () => SeriesDetailResponse(
          schemaVersion: '1.0',
          series: _metadata(),
          episodes: _episodesNewestFirst(),
        ),
      ),
    );

    await tester.pumpWidget(_wrap(repository, slug: 'gece-vardiyasi'));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('renders cover, metadata and episode list on success', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeSeriesRepository(
      (slug) async => SeriesDetailResponse(
        schemaVersion: '1.0',
        series: _metadata(),
        episodes: _episodesNewestFirst(),
      ),
    );

    await tester.pumpWidget(_wrap(repository, slug: 'gece-vardiyasi'));
    await tester.pumpAndSettle();

    // Üst kısım: kapak (AppBar başlığı olarak da görünür), eyebrow, creator.
    expect(find.text('Gece Vardiyası'), findsWidgets); // AppBar + başlık
    expect(find.text('Zamanı geri saran bir teslimat'), findsOneWidget);
    expect(find.text('Panelya Originals'), findsOneWidget);

    await _revealText(tester, 'Ece için gece vardiyası uzun bir açıklamadır.');
    expect(find.text('Devam Ediyor'), findsOneWidget);
    expect(find.text('Gizem'), findsOneWidget);
    expect(find.text('Bilim Kurgu'), findsOneWidget);
    expect(find.text('4.9'), findsOneWidget);
    expect(find.textContaining('12,8 B'), findsOneWidget);

    // "Okumaya başla" en düşük numaralı (ilk) bölümü referans almalı.
    await _revealText(tester, 'Okumaya başla · Bölüm 1');

    // Bölüm listesi: sequence etiketi, başlık ve tarih.
    await _revealText(tester, 'Kayıp Dakika');
    expect(find.textContaining('18 Temmuz 2026'), findsOneWidget);
    await _revealText(tester, 'Yarınki Adres');
    await _revealText(tester, 'Son Teslimat');
  });

  testWidgets('"Okumaya başla" navigates to the first episode, not the latest', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeSeriesRepository(
      (slug) async => SeriesDetailResponse(
        schemaVersion: '1.0',
        series: _metadata(),
        episodes: _episodesNewestFirst(),
      ),
    );

    await tester.pumpWidget(
      _wrapWithRouter(repository, slug: 'gece-vardiyasi'),
    );
    await tester.pumpAndSettle();

    await _revealText(tester, 'Okumaya başla · Bölüm 1');
    await tester.tap(find.text('Okumaya başla · Bölüm 1'));
    await tester.pumpAndSettle();

    expect(find.text('READER:gece-vardiyasi/bolum-1'), findsOneWidget);
  });

  testWidgets('tapping an episode tile navigates to that specific episode', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeSeriesRepository(
      (slug) async => SeriesDetailResponse(
        schemaVersion: '1.0',
        series: _metadata(),
        episodes: _episodesNewestFirst(),
      ),
    );

    await tester.pumpWidget(
      _wrapWithRouter(repository, slug: 'gece-vardiyasi'),
    );
    await tester.pumpAndSettle();

    await _revealText(tester, 'Yarınki Adres');
    await tester.tap(find.text('Yarınki Adres'));
    await tester.pumpAndSettle();

    expect(find.text('READER:gece-vardiyasi/bolum-2'), findsOneWidget);
  });

  testWidgets('shows the empty state when the series has no episodes', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final repository = _FakeSeriesRepository(
      (slug) async => SeriesDetailResponse(
        schemaVersion: '1.0',
        series: _metadata(),
        episodes: const [],
      ),
    );

    await tester.pumpWidget(_wrap(repository, slug: 'gece-vardiyasi'));
    await tester.pumpAndSettle();

    expect(
      find.text('Bu serinin henüz yayınlanmış bölümü yok.'),
      findsOneWidget,
    );
  });

  testWidgets('shows an error view with a working retry button', (
    tester,
  ) async {
    usePhoneViewport(tester);
    var attempt = 0;
    final repository = _FakeSeriesRepository((slug) async {
      attempt += 1;
      if (attempt == 1) {
        throw const HttpStatusException(
          statusCode: 404,
          path: '/api/series/gece-vardiyasi',
          errorCode: 'series_not_found',
        );
      }
      return SeriesDetailResponse(
        schemaVersion: '1.0',
        series: _metadata(),
        episodes: _episodesNewestFirst(),
      );
    });

    await tester.pumpWidget(_wrap(repository, slug: 'gece-vardiyasi'));
    await tester.pumpAndSettle();

    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(find.text('Aradığınız içerik bulunamadı.'), findsOneWidget);

    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();

    await _revealText(tester, 'Okumaya başla · Bölüm 1');
  });

  group('cihaz-yerel "kaldığın yerden devam et" kaydı', () {
    testWidgets(
      'with no local progress record, shows only "Okumaya başla" (no '
      '"Devam et"/"Baştan başla" pair)',
      (tester) async {
        usePhoneViewport(tester);
        final repository = _FakeSeriesRepository(
          (slug) async => SeriesDetailResponse(
            schemaVersion: '1.0',
            series: _metadata(),
            episodes: _episodesNewestFirst(),
          ),
        );

        await tester.pumpWidget(
          _wrap(
            repository,
            slug: 'gece-vardiyasi',
            progressRepository: _FakeReadingProgressRepository(),
          ),
        );
        await tester.pumpAndSettle();

        await _revealText(tester, 'Okumaya başla · Bölüm 1');
        expect(find.textContaining('Devam et:'), findsNothing);
        expect(find.text('Baştan başla'), findsNothing);
      },
    );

    testWidgets(
      'with a local progress record, shows "Devam et: Bölüm N" as the '
      'primary action and "Baştan başla" as a secondary action, each '
      'navigating to the expected episode',
      (tester) async {
        usePhoneViewport(tester);
        final repository = _FakeSeriesRepository(
          (slug) async => SeriesDetailResponse(
            schemaVersion: '1.0',
            series: _metadata(),
            episodes: _episodesNewestFirst(),
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
          _wrapWithRouter(
            repository,
            slug: 'gece-vardiyasi',
            progressRepository: progressRepository,
          ),
        );
        await tester.pumpAndSettle();

        // Eski "Okumaya başla" artık görünmüyor; yerine "Devam et" +
        // "Baştan başla" çifti var.
        expect(find.textContaining('Okumaya başla'), findsNothing);
        await _revealText(tester, 'Devam et: Bölüm 2');
        expect(find.text('Baştan başla'), findsOneWidget);

        await tester.tap(find.text('Devam et: Bölüm 2'));
        await tester.pumpAndSettle();

        expect(find.text('READER:gece-vardiyasi/bolum-2'), findsOneWidget);
      },
    );

    testWidgets(
      '"Baştan başla" always navigates to the first episode (lowest '
      'number), even when the continue target is a later episode',
      (tester) async {
        usePhoneViewport(tester);
        final repository = _FakeSeriesRepository(
          (slug) async => SeriesDetailResponse(
            schemaVersion: '1.0',
            series: _metadata(),
            episodes: _episodesNewestFirst(),
          ),
        );
        final progressRepository = _FakeReadingProgressRepository({
          'gece-vardiyasi': ReadingProgress(
            seriesSlug: 'gece-vardiyasi',
            seriesTitle: 'Gece Vardiyası',
            episodeSlug: 'bolum-3',
            episodeNumber: 3,
            updatedAt: DateTime(2026, 7, 18),
            completed: true,
          ),
        });

        await tester.pumpWidget(
          _wrapWithRouter(
            repository,
            slug: 'gece-vardiyasi',
            progressRepository: progressRepository,
          ),
        );
        await tester.pumpAndSettle();

        await _revealText(tester, 'Baştan başla');
        await tester.tap(find.text('Baştan başla'));
        await tester.pumpAndSettle();

        expect(find.text('READER:gece-vardiyasi/bolum-1'), findsOneWidget);
      },
    );
  });
}
