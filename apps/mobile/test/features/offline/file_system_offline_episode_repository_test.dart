import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:panelya_mobile/core/api/api_exception.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/offline/data/file_system_offline_episode_repository.dart';

EpisodeManifestResponse _manifest({
  String seriesSlug = 'gece-vardiyasi',
  String seriesTitle = 'Gece Vardiyası',
  String episodeSlug = 'bolum-1',
  int number = 1,
  List<StoryPanel> panels = const [],
}) {
  return EpisodeManifestResponse(
    schemaVersion: '1.0',
    series: EpisodeManifestSeriesRef(slug: seriesSlug, title: seriesTitle),
    episode: Episode(
      slug: episodeSlug,
      number: number,
      title: 'Kayıp Dakika',
      publishedAt: '18 Temmuz 2026',
      readTime: '7 dk',
      panels: panels,
    ),
    navigation: const EpisodeNavigation(previous: null, next: null),
  );
}

const _panelWithImage = StoryPanel(
  id: 'panel-1',
  scene: 'Ece pencereden dışarı bakıyor',
  tone: PanelTone.mint,
  image: StoryPanelImage(
    src: 'http://localhost:3000/panel-1.png',
    alt: 'Ece pencereden dışarı bakıyor',
    width: 800,
    height: 1200,
  ),
);

const _secondPanelWithImage = StoryPanel(
  id: 'panel-2',
  scene: 'Sokak lambası titriyor',
  tone: PanelTone.coral,
  image: StoryPanelImage(
    src: 'http://localhost:3000/panel-2.png',
    alt: 'Sokak lambası titriyor',
    width: 800,
    height: 1200,
  ),
);

// `PanelTone.unknown` KASITLI olarak kullanılmıyor: bu enum'un `toJson()`'ı
// (bkz. üretilen `panel_tone.dart`) ham sunucu değerini saklamadığı için
// `unknown` için bilerek fırlatır — bu, indirme testinin amacı olan
// "görselsiz panel" senaryosuyla ilgisiz bir kenar durumdur.
const _panelWithoutImage = StoryPanel(
  id: 'panel-3',
  scene: 'Sokak lambası titriyor',
  tone: PanelTone.coral,
);

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('offline_repo_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('isDownloaded / loadDownloaded (henüz indirilmemiş)', () {
    test('isDownloaded false döner ve loadDownloaded null döner', () async {
      final repository = FileSystemOfflineEpisodeRepository(tempDir);

      expect(
        await repository.isDownloaded('gece-vardiyasi', 'bolum-1'),
        isFalse,
      );
      expect(
        await repository.loadDownloaded('gece-vardiyasi', 'bolum-1'),
        isNull,
      );
    });
  });

  group('downloadEpisode', () {
    test(
      'tüm panel görsellerini indirir, ilerlemeyi 0-1 arası yayınlar ve '
      'sonunda isDownloaded true olur',
      () async {
        final requestedUrls = <String>[];
        final mockClient = MockClient((request) async {
          requestedUrls.add(request.url.toString());
          return http.Response.bytes(
            utf8.encode('bytes-for-${request.url.path}'),
            200,
          );
        });
        final repository = FileSystemOfflineEpisodeRepository(
          tempDir,
          httpClient: mockClient,
        );
        final manifest = _manifest(
          panels: const [_panelWithImage, _secondPanelWithImage],
        );

        final progressEvents = await repository
            .downloadEpisode(apiOrigin: 'http://localhost:3000', manifest: manifest)
            .toList();

        expect(progressEvents, [0.5, 1.0]);
        expect(requestedUrls, [
          'http://localhost:3000/panel-1.png',
          'http://localhost:3000/panel-2.png',
        ]);
        expect(
          await repository.isDownloaded('gece-vardiyasi', 'bolum-1'),
          isTrue,
        );
      },
    );

    test(
      'panel görseli olmayan bir bölüm bile tek adımda 1.0\'a tamamlanır '
      've isDownloaded true olur (indirilecek hiçbir bayt yok)',
      () async {
        final mockClient = MockClient((request) async {
          throw StateError('Görselsiz panel için hiçbir istek yapılmamalı');
        });
        final repository = FileSystemOfflineEpisodeRepository(
          tempDir,
          httpClient: mockClient,
        );
        final manifest = _manifest(panels: const [_panelWithoutImage]);

        final progressEvents = await repository
            .downloadEpisode(apiOrigin: 'http://localhost:3000', manifest: manifest)
            .toList();

        expect(progressEvents, [1.0]);
        expect(
          await repository.isDownloaded('gece-vardiyasi', 'bolum-1'),
          isTrue,
        );
      },
    );

    test(
      'bir panel görseli indirilemezse (HTTP 500) stream hatayla kapanır, '
      'kısmi dosyalar silinir ve isDownloaded false KALIR',
      () async {
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('panel-1')) {
            return http.Response('', 200);
          }
          return http.Response('', 500);
        });
        final repository = FileSystemOfflineEpisodeRepository(
          tempDir,
          httpClient: mockClient,
        );
        final manifest = _manifest(
          panels: const [_panelWithImage, _secondPanelWithImage],
        );

        await expectLater(
          repository.downloadEpisode(
            apiOrigin: 'http://localhost:3000',
            manifest: manifest,
          ),
          emitsInOrder([0.5, emitsError(isA<HttpStatusException>())]),
        );

        expect(
          await repository.isDownloaded('gece-vardiyasi', 'bolum-1'),
          isFalse,
        );
        // Yarım kalan indirmenin dizini de temizlenmiş olmalı — kısmi
        // dosyalar disk üzerinde asılı kalmaz.
        expect(
          Directory(
            '${tempDir.path}/offline_episodes/gece-vardiyasi/bolum-1',
          ).existsSync(),
          isFalse,
        );
      },
    );

    test(
      'ağ hatası (SocketException) NetworkException olarak yüzeye çıkar',
      () async {
        final mockClient = MockClient((request) async {
          throw const SocketException('bağlantı yok');
        });
        final repository = FileSystemOfflineEpisodeRepository(
          tempDir,
          httpClient: mockClient,
        );
        final manifest = _manifest(panels: const [_panelWithImage]);

        await expectLater(
          repository.downloadEpisode(
            apiOrigin: 'http://localhost:3000',
            manifest: manifest,
          ),
          emitsError(isA<NetworkException>()),
        );
      },
    );
  });

  group('loadDownloaded (indirilmiş)', () {
    test(
      'manifesti ve her panelin yerel dosyasını (görselsiz panel için null) '
      'döner',
      () async {
        final mockClient = MockClient(
          (request) async => http.Response.bytes([1, 2, 3], 200),
        );
        final repository = FileSystemOfflineEpisodeRepository(
          tempDir,
          httpClient: mockClient,
        );
        final manifest = _manifest(
          panels: const [_panelWithImage, _panelWithoutImage],
        );
        await repository
            .downloadEpisode(apiOrigin: 'http://localhost:3000', manifest: manifest)
            .drain<void>();

        final content = await repository.loadDownloaded(
          'gece-vardiyasi',
          'bolum-1',
        );

        expect(content, isNotNull);
        expect(content!.manifest.episode.slug, 'bolum-1');
        expect(content.manifest.episode.panels, hasLength(2));
        expect(content.panelImageFiles, hasLength(2));
        expect(content.panelImageFiles[0], isNotNull);
        expect(content.panelImageFiles[0]!.existsSync(), isTrue);
        expect(
          await content.panelImageFiles[0]!.readAsBytes(),
          [1, 2, 3],
        );
        // Görselsiz panel: index'te her zaman null.
        expect(content.panelImageFiles[1], isNull);
      },
    );
  });

  group('deleteDownload', () {
    test('indirilmiş bir bölümü ve tüm yerel dosyalarını siler', () async {
      final mockClient = MockClient(
        (request) async => http.Response.bytes([1], 200),
      );
      final repository = FileSystemOfflineEpisodeRepository(
        tempDir,
        httpClient: mockClient,
      );
      final manifest = _manifest(panels: const [_panelWithImage]);
      await repository
          .downloadEpisode(apiOrigin: 'http://localhost:3000', manifest: manifest)
          .drain<void>();
      expect(
        await repository.isDownloaded('gece-vardiyasi', 'bolum-1'),
        isTrue,
      );

      await repository.deleteDownload('gece-vardiyasi', 'bolum-1');

      expect(
        await repository.isDownloaded('gece-vardiyasi', 'bolum-1'),
        isFalse,
      );
      expect(
        await repository.loadDownloaded('gece-vardiyasi', 'bolum-1'),
        isNull,
      );
    });

    test(
      'zaten indirilmemiş bir bölüm için sessizce hiçbir şey yapmaz',
      () async {
        final repository = FileSystemOfflineEpisodeRepository(tempDir);
        await repository.deleteDownload('gece-vardiyasi', 'hic-yok');
        expect(
          await repository.isDownloaded('gece-vardiyasi', 'hic-yok'),
          isFalse,
        );
      },
    );
  });

  group('listDownloaded (bkz. "İndirilenler" ekranı, downloads_screen.dart)', () {
    test('hiç indirme yoksa boş liste döner', () async {
      final repository = FileSystemOfflineEpisodeRepository(tempDir);
      expect(await repository.listDownloaded(), isEmpty);
    });

    test(
      'birden fazla seri/bölüm indirildiğinde hepsini, seri adına sonra '
      'bölüm numarasına göre sıralı döner; boyutlar gerçek dosya '
      'baytlarını yansıtır',
      () async {
        final mockClient = MockClient(
          (request) async => http.Response.bytes([1, 2, 3, 4], 200),
        );
        final repository = FileSystemOfflineEpisodeRepository(
          tempDir,
          httpClient: mockClient,
        );

        // "Z Serisi" alfabetik olarak "Gece Vardiyası"ndan SONRA gelir;
        // sıralamanın dosya sistemi/indirme sırasına değil seri adına
        // dayandığını doğrulamak için bilerek TERS sırayla indirilir.
        await repository
            .downloadEpisode(
              apiOrigin: 'http://localhost:3000',
              manifest: _manifest(
                seriesSlug: 'z-serisi',
                seriesTitle: 'Z Serisi',
                episodeSlug: 'bolum-1',
                number: 1,
                panels: const [_panelWithImage],
              ),
            )
            .drain<void>();
        await repository
            .downloadEpisode(
              apiOrigin: 'http://localhost:3000',
              manifest: _manifest(
                seriesSlug: 'gece-vardiyasi',
                episodeSlug: 'bolum-2',
                number: 2,
                panels: const [_panelWithImage, _secondPanelWithImage],
              ),
            )
            .drain<void>();
        await repository
            .downloadEpisode(
              apiOrigin: 'http://localhost:3000',
              manifest: _manifest(
                seriesSlug: 'gece-vardiyasi',
                episodeSlug: 'bolum-1',
                number: 1,
                panels: const [_panelWithImage],
              ),
            )
            .drain<void>();

        final downloaded = await repository.listDownloaded();

        expect(downloaded, hasLength(3));
        expect(
          downloaded.map((e) => '${e.seriesSlug}/${e.episodeSlug}').toList(),
          ['gece-vardiyasi/bolum-1', 'gece-vardiyasi/bolum-2', 'z-serisi/bolum-1'],
        );
        // 1 panelli bölüm: manifest.json + 4 baytlık tek panel dosyası.
        final single = downloaded.firstWhere(
          (e) => e.episodeSlug == 'bolum-1' && e.seriesSlug == 'gece-vardiyasi',
        );
        expect(single.sizeBytes, greaterThan(4));
        // 2 panelli bölüm daha büyük olmalı (aynı manifest yükü + iki kat
        // panel bayt'ı).
        final double_ = downloaded.firstWhere((e) => e.episodeSlug == 'bolum-2');
        expect(double_.sizeBytes, greaterThan(single.sizeBytes));
      },
    );

    test(
      'yarım kalan (manifest.json yazılmamış) bir indirme dizini listede '
      'GÖRÜNMEZ',
      () async {
        final repository = FileSystemOfflineEpisodeRepository(tempDir);
        // Gerçek bir indirmenin ARA durumunu taklit eder: dizin ve
        // panels/ var ama manifest.json henüz yazılmadı (bkz.
        // `downloadEpisode` doc yorumu — bilerek EN SON yazılır).
        final partialDir = Directory(
          '${tempDir.path}/offline_episodes/yarim-seri/bolum-1/panels',
        );
        await partialDir.create(recursive: true);
        await File('${partialDir.path}/0').writeAsBytes([1, 2, 3]);

        expect(await repository.listDownloaded(), isEmpty);
      },
    );
  });
}
