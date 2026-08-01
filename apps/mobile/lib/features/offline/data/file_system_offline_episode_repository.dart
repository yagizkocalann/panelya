import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/api/api_exception.dart';
import '../../../core/api/media_url.dart';
import '../../../core/contracts/generated/generated.dart';
import '../domain/downloaded_episode.dart';
import '../domain/offline_episode_content.dart';
import '../domain/offline_episode_repository.dart';

/// [OfflineEpisodeRepository]'nin tek implementasyonu: her bölümü
/// `<uygulama belgeleri>/offline_episodes/<seriesSlug>/<episodeSlug>/`
/// altında saklar —
///
/// - `manifest.json`: `EpisodeManifestResponse.toJson()` (ağdan gelenle
///   AYNI şema; üretilen sınıf zaten `toJson`/`fromJson` taşıdığı için
///   ayrı bir yerel şema icat edilmedi).
/// - `panels/<index>`: panelin `image.src`'inden indirilen HAM görsel
///   bayt'ları (uzantı YOK — `Image.file` içeriği zaten format
///   sniffing'le çözer, bkz. Flutter SDK; bu, seçilen bir varyanta göre
///   uzantı tahmin etmeyi gereksiz kılar).
///
/// Neden [manifest.json]'ın YAZILMASI indirmenin SON adımı (bkz.
/// [downloadEpisode]): [isDownloaded] yalnız bu dosyanın varlığına bakar;
/// tüm panel görselleri başarıyla indirilmeden bu dosya yazılmazsa, yarıda
/// kesilen bir indirme asla "indirilmiş" görünmez — bir sonraki deneme
/// baştan başlar, bozuk/yarım bir yerel durum hiç ortaya çıkmaz.
class FileSystemOfflineEpisodeRepository implements OfflineEpisodeRepository {
  FileSystemOfflineEpisodeRepository(this._baseDirectory, {http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final Directory _baseDirectory;
  final http.Client _httpClient;

  Directory _episodeDirectory(String seriesSlug, String episodeSlug) {
    return Directory(
      '${_baseDirectory.path}/offline_episodes/$seriesSlug/$episodeSlug',
    );
  }

  File _manifestFile(String seriesSlug, String episodeSlug) {
    return File(
      '${_episodeDirectory(seriesSlug, episodeSlug).path}/manifest.json',
    );
  }

  File _panelFile(String seriesSlug, String episodeSlug, int index) {
    return File(
      '${_episodeDirectory(seriesSlug, episodeSlug).path}/panels/$index',
    );
  }

  @override
  Future<bool> isDownloaded(String seriesSlug, String episodeSlug) {
    return _manifestFile(seriesSlug, episodeSlug).exists();
  }

  @override
  Future<OfflineEpisodeContent?> loadDownloaded(
    String seriesSlug,
    String episodeSlug,
  ) async {
    final manifestFile = _manifestFile(seriesSlug, episodeSlug);
    if (!manifestFile.existsSync()) return null;

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    } on FormatException {
      // Bozuk yerel dosya: kritik veri değil, sessizce "indirilmemiş"
      // kabul edilir — okuyucu normal ağ akışına düşer (bkz.
      // `readerContentProvider`).
      return null;
    }
    final manifest = EpisodeManifestResponse.fromJson(json);

    final panelImageFiles = <File?>[];
    for (var i = 0; i < manifest.episode.panels.length; i++) {
      final panel = manifest.episode.panels[i];
      if (panel.image == null) {
        panelImageFiles.add(null);
        continue;
      }
      final file = _panelFile(seriesSlug, episodeSlug, i);
      panelImageFiles.add(file.existsSync() ? file : null);
    }

    return OfflineEpisodeContent(
      manifest: manifest,
      panelImageFiles: panelImageFiles,
    );
  }

  @override
  Stream<double> downloadEpisode({
    required String apiOrigin,
    required EpisodeManifestResponse manifest,
  }) async* {
    final seriesSlug = manifest.series.slug;
    final episodeSlug = manifest.episode.slug;
    final episodeDir = _episodeDirectory(seriesSlug, episodeSlug);
    final panelsWithImage = manifest.episode.panels
        .where((panel) => panel.image != null)
        .length;
    // Panel görseli olmayan bir bölüm bile geçerlidir (bkz.
    // `_PanelBlock`'un görselsiz geri düşüşü) — bu durumda indirilecek
    // hiçbir bayt yok, tek adım doğrudan `1.0`'a tamamlanır.
    final totalSteps = panelsWithImage == 0 ? 1 : panelsWithImage;

    try {
      await episodeDir.create(recursive: true);
      final panelsDir = Directory('${episodeDir.path}/panels');
      await panelsDir.create(recursive: true);

      var completedSteps = 0;
      for (var i = 0; i < manifest.episode.panels.length; i++) {
        final image = manifest.episode.panels[i].image;
        if (image == null) continue;

        final bytes = await _downloadBytes(resolveMediaUrl(apiOrigin, image.src));
        await _panelFile(seriesSlug, episodeSlug, i).writeAsBytes(bytes);

        completedSteps++;
        yield completedSteps / totalSteps;
      }

      // Bkz. sınıf doc yorumu: manifest en SON yazılır, [isDownloaded]
      // yalnız bundan sonra `true` döner.
      await _manifestFile(
        seriesSlug,
        episodeSlug,
      ).writeAsString(jsonEncode(manifest.toJson()));

      if (panelsWithImage == 0) yield 1.0;
    } catch (_) {
      // Yarım kalan indirmeyi temizle (bkz. sınıf doc yorumu — bozuk/yarım
      // bir "indirilmiş" durumu asla kalmamalı).
      if (await episodeDir.exists()) {
        await episodeDir.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<List<int>> _downloadBytes(String url) async {
    http.Response response;
    try {
      response = await _httpClient.get(Uri.parse(url));
    } on SocketException catch (cause) {
      throw NetworkException('Sunucuya bağlanılamadı: $url', cause: cause);
    } on http.ClientException catch (cause) {
      throw NetworkException('Ağ hatası: $url', cause: cause);
    }
    if (response.statusCode != 200) {
      throw HttpStatusException(statusCode: response.statusCode, path: url);
    }
    return response.bodyBytes;
  }

  @override
  Future<void> deleteDownload(String seriesSlug, String episodeSlug) async {
    final dir = _episodeDirectory(seriesSlug, episodeSlug);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  @override
  Future<List<DownloadedEpisode>> listDownloaded() async {
    final root = Directory('${_baseDirectory.path}/offline_episodes');
    if (!await root.exists()) return const [];

    final results = <DownloadedEpisode>[];
    await for (final seriesEntity in root.list()) {
      if (seriesEntity is! Directory) continue;
      await for (final episodeEntity in seriesEntity.list()) {
        if (episodeEntity is! Directory) continue;

        final manifestFile = File('${episodeEntity.path}/manifest.json');
        // Manifest yoksa bu ya hiç tamamlanmamış (bkz. [downloadEpisode]
        // doc yorumu) ya da tam o an silinmekte olan bir dizin — her iki
        // durumda da listede GÖRÜNMEMELİ.
        if (!await manifestFile.exists()) continue;

        final EpisodeManifestResponse manifest;
        try {
          final json =
              jsonDecode(await manifestFile.readAsString())
                  as Map<String, dynamic>;
          manifest = EpisodeManifestResponse.fromJson(json);
        } on FormatException {
          continue;
        }

        var sizeBytes = await manifestFile.length();
        final panelsDir = Directory('${episodeEntity.path}/panels');
        if (await panelsDir.exists()) {
          await for (final panelEntity in panelsDir.list()) {
            if (panelEntity is File) sizeBytes += await panelEntity.length();
          }
        }

        results.add(
          DownloadedEpisode(
            seriesSlug: manifest.series.slug,
            seriesTitle: manifest.series.title,
            episodeSlug: manifest.episode.slug,
            episodeNumber: manifest.episode.number,
            episodeTitle: manifest.episode.title,
            sizeBytes: sizeBytes,
          ),
        );
      }
    }

    results.sort((a, b) {
      final byTitle = a.seriesTitle.compareTo(b.seriesTitle);
      return byTitle != 0 ? byTitle : a.episodeNumber.compareTo(b.episodeNumber);
    });
    return results;
  }
}
