import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/offline/domain/downloaded_episode.dart';
import 'package:panelya_mobile/features/offline/domain/offline_episode_content.dart';
import 'package:panelya_mobile/features/offline/domain/offline_episode_repository.dart';
import 'package:panelya_mobile/features/offline/presentation/downloads_screen.dart';
import 'package:panelya_mobile/features/offline/presentation/offline_providers.dart';
import 'package:panelya_mobile/features/reader/domain/reader_repository.dart';
import 'package:panelya_mobile/features/reader/presentation/reader_providers.dart';

/// In-memory sahte çevrimdışı depo: [DownloadedEpisode] listesini doğrudan
/// tutar (gerçek dosya IO'suna gerek yok — bu ekran yalnız
/// `listDownloaded`/`deleteDownload` çağırır, bkz. `downloads_screen.dart`).
class _FakeOfflineEpisodeRepository implements OfflineEpisodeRepository {
  _FakeOfflineEpisodeRepository(List<DownloadedEpisode> seed)
    : _episodes = [...seed];

  final List<DownloadedEpisode> _episodes;
  final List<String> deletedEpisodeSlugs = [];

  @override
  Future<bool> isDownloaded(String seriesSlug, String episodeSlug) async =>
      _episodes.any(
        (e) => e.seriesSlug == seriesSlug && e.episodeSlug == episodeSlug,
      );

  @override
  Future<OfflineEpisodeContent?> loadDownloaded(
    String seriesSlug,
    String episodeSlug,
  ) async => null;

  @override
  Stream<double> downloadEpisode({
    required String apiOrigin,
    required EpisodeManifestResponse manifest,
  }) async* {
    yield 1.0;
  }

  @override
  Future<void> deleteDownload(String seriesSlug, String episodeSlug) async {
    _episodes.removeWhere(
      (e) => e.seriesSlug == seriesSlug && e.episodeSlug == episodeSlug,
    );
    deletedEpisodeSlugs.add(episodeSlug);
  }

  @override
  Future<List<DownloadedEpisode>> listDownloaded() async =>
      List.unmodifiable(_episodes);
}

/// Bu ekran indirilmiş bölümleri listelediği için okuyucu repository'si
/// pratikte hiç çağrılmaz (bkz. `downloads_screen.dart` — `resolveManifest`
/// yorumu); yine de arayüz gerektirdiği için zararsız bir manifest döner.
class _FakeReaderRepository implements ReaderRepository {
  @override
  Future<EpisodeManifestResponse> fetchEpisodeManifest(
    String seriesSlug,
    String episodeSlug,
  ) async {
    return EpisodeManifestResponse(
      schemaVersion: '1.0',
      series: EpisodeManifestSeriesRef(slug: seriesSlug, title: seriesSlug),
      episode: Episode(
        slug: episodeSlug,
        number: 1,
        title: episodeSlug,
        publishedAt: '',
        readTime: '',
        panels: const [],
      ),
      navigation: const EpisodeNavigation(previous: null, next: null),
    );
  }
}

/// `isEpisodeDownloadedProvider`'ın belirli bir bölüm için o anki değerini
/// düz metin olarak gösteren prob widget. Regresyon testi için: seri/
/// okuyucu ekranındaki indirme düğmesi bu provider'ı okur; "İndirilenler"
/// ekranındaki "Tümünü sil" bu provider'ı tazelemezse o ekranlar dosyalar
/// silinmiş olsa bile eski "indirilmiş" durumunu göstermeye devam eder
/// (bkz. `episode_download_button.dart` ve `downloads_screen.dart`daki
/// `_confirmDeleteAll` düzeltmesi).
class _IsDownloadedProbe extends ConsumerWidget {
  const _IsDownloadedProbe(this.key_);

  final OfflineEpisodeKey key_;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDownloaded = ref.watch(isEpisodeDownloadedProvider(key_)).asData?.value;
    return Text('probe:$isDownloaded');
  }
}

Widget _wrapWithDownloadedProbe(
  _FakeOfflineEpisodeRepository repository,
  OfflineEpisodeKey probeKey,
) {
  final router = GoRouter(
    initialLocation: '/downloads',
    routes: [
      GoRoute(
        path: '/downloads',
        builder: (context, state) => Column(
          children: [
            Expanded(child: const DownloadsScreen()),
            _IsDownloadedProbe(probeKey),
          ],
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      offlineEpisodeRepositoryProvider.overrideWithValue(repository),
      readerRepositoryProvider.overrideWithValue(_FakeReaderRepository()),
    ],
    child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
  );
}

Widget _wrap(_FakeOfflineEpisodeRepository repository) {
  final router = GoRouter(
    initialLocation: '/downloads',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/downloads',
        builder: (context, state) => const DownloadsScreen(),
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
      offlineEpisodeRepositoryProvider.overrideWithValue(repository),
      readerRepositoryProvider.overrideWithValue(_FakeReaderRepository()),
    ],
    child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
  );
}

DownloadedEpisode _episode({
  String seriesSlug = 'gece-vardiyasi',
  String seriesTitle = 'Gece Vardiyası',
  String episodeSlug = 'bolum-1',
  int episodeNumber = 1,
  String episodeTitle = 'Kayıp Dakika',
  int sizeBytes = 1024,
}) {
  return DownloadedEpisode(
    seriesSlug: seriesSlug,
    seriesTitle: seriesTitle,
    episodeSlug: episodeSlug,
    episodeNumber: episodeNumber,
    episodeTitle: episodeTitle,
    sizeBytes: sizeBytes,
  );
}

void main() {
  testWidgets(
    'boş durumda "henüz indirilmiş bölüm yok" mesajı gösterir ve "tüm '
    'indirmeleri sil" aksiyonu HİÇ görünmez (ADR-010)',
    (tester) async {
      await tester.pumpWidget(_wrap(_FakeOfflineEpisodeRepository(const [])));
      await tester.pumpAndSettle();

      expect(find.text('Henüz indirilmiş bir bölüm yok.'), findsOneWidget);
      expect(find.byTooltip('Tüm indirmeleri sil'), findsNothing);
    },
  );

  testWidgets(
    'indirilmiş bölümleri seri/bölüm başlığı ve boyutuyla listeler',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          _FakeOfflineEpisodeRepository([
            _episode(sizeBytes: 2048),
            _episode(
              seriesSlug: 'yarinki-ses',
              seriesTitle: 'Yarınki Ses',
              episodeSlug: 'bolum-3',
              episodeNumber: 3,
              episodeTitle: 'Uzak Sinyal',
              sizeBytes: 512,
            ),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gece Vardiyası'), findsOneWidget);
      expect(find.text('Bölüm 1: Kayıp Dakika'), findsOneWidget);
      expect(find.text('2.0 KB'), findsOneWidget);

      expect(find.text('Yarınki Ses'), findsOneWidget);
      expect(find.text('Bölüm 3: Uzak Sinyal'), findsOneWidget);
      expect(find.text('512 B'), findsOneWidget);

      // Toplam özet.
      expect(find.text('2 bölüm · 2.5 KB'), findsOneWidget);
    },
  );

  testWidgets(
    'bir satıra dokunmak o bölümün okuyucusuna gider',
    (tester) async {
      await tester.pumpWidget(
        _wrap(_FakeOfflineEpisodeRepository([_episode()])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bölüm 1: Kayıp Dakika'));
      await tester.pumpAndSettle();

      expect(
        find.text('READER:gece-vardiyasi/bolum-1'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'bir satırın "indirildi" ikonuna dokunup silmeyi onaylamak yalnız o '
    'bölümü listeden kaldırır',
    (tester) async {
      final repository = _FakeOfflineEpisodeRepository([
        _episode(),
        _episode(
          seriesSlug: 'yarinki-ses',
          seriesTitle: 'Yarınki Ses',
          episodeSlug: 'bolum-3',
          episodeNumber: 3,
          episodeTitle: 'Uzak Sinyal',
        ),
      ]);

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      expect(find.byTooltip('İndirildi · kaldırmak için dokunun'), findsNWidgets(2));

      await tester.tap(find.byTooltip('İndirildi · kaldırmak için dokunun').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();

      expect(repository.deletedEpisodeSlugs, hasLength(1));
      expect(find.byTooltip('İndirildi · kaldırmak için dokunun'), findsOneWidget);
    },
  );

  testWidgets(
    '"tüm indirmeleri sil" onaylandığında hepsini siler ve boş duruma döner',
    (tester) async {
      final repository = _FakeOfflineEpisodeRepository([
        _episode(),
        _episode(
          seriesSlug: 'yarinki-ses',
          seriesTitle: 'Yarınki Ses',
          episodeSlug: 'bolum-3',
          episodeNumber: 3,
          episodeTitle: 'Uzak Sinyal',
        ),
      ]);

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Tüm indirmeleri sil'));
      await tester.pumpAndSettle();

      expect(find.text('Tüm indirmeleri sil'), findsWidgets);
      await tester.tap(find.text('Tümünü sil'));
      await tester.pumpAndSettle();

      expect(repository.deletedEpisodeSlugs.toSet(), {'bolum-1', 'bolum-3'});
      expect(find.text('Henüz indirilmiş bir bölüm yok.'), findsOneWidget);
    },
  );

  testWidgets(
    '"tüm indirmeleri sil" -> "Vazgeç" hiçbir şeyi silmez',
    (tester) async {
      final repository = _FakeOfflineEpisodeRepository([_episode()]);

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Tüm indirmeleri sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();

      expect(repository.deletedEpisodeSlugs, isEmpty);
      expect(find.byTooltip('İndirildi · kaldırmak için dokunun'), findsOneWidget);
    },
  );

  testWidgets(
    'the app bar offers a home button that navigates to "/" and meets the '
    '44x44 touch target minimum',
    (tester) async {
      await tester.pumpWidget(
        _wrap(_FakeOfflineEpisodeRepository(const [])),
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

  testWidgets(
    '"tüm indirmeleri sil" onaylandığında isEpisodeDownloadedProvider da '
    'her bölüm için tazelenir (regresyon: aksi halde seri/okuyucu ekranı '
    'dosyalar silinmiş olsa bile eski "indirilmiş" durumunu gösterirdi)',
    (tester) async {
      const probeKey = (
        seriesSlug: 'gece-vardiyasi',
        episodeSlug: 'bolum-1',
      );
      final repository = _FakeOfflineEpisodeRepository([_episode()]);

      await tester.pumpWidget(
        _wrapWithDownloadedProbe(repository, probeKey),
      );
      await tester.pumpAndSettle();

      expect(find.text('probe:true'), findsOneWidget);

      await tester.tap(find.byTooltip('Tüm indirmeleri sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tümünü sil'));
      await tester.pumpAndSettle();

      expect(find.text('probe:false'), findsOneWidget);
    },
  );
}
