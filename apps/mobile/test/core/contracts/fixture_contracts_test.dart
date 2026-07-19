import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/core/contracts/catalog_response.dart';
import 'package:panelya_mobile/core/contracts/episode_manifest_response.dart';
import 'package:panelya_mobile/core/contracts/series_detail_response.dart';
import 'package:panelya_mobile/core/contracts/story_panel.dart';

/// Bu testler `packages/contracts/fixtures/` altındaki SALT OKUNUR, ortak
/// (main'den `codex/mobile`'a merge edilen) sentetik fixture'ları dosya
/// sisteminden okuyup mevcut `lib/core/contracts` modelleriyle ayrıştırır.
/// Fixture içerikleri buraya kopyalanmaz; `packages/contracts/` tek
/// doğruluk kaynağı olarak kalır (bkz. packages/contracts/README.md
/// "Değişiklik kuralı"). Bu paket dosyalarına buradan YAZILMAZ.
///
/// `flutter test` her zaman paket kökünden (`apps/mobile`) çalıştırıldığı
/// için repo köküne göre relative yol `../../packages/contracts/fixtures`
/// olur.
const _fixturesDir = '../../packages/contracts/fixtures';

Map<String, dynamic> _readFixture(String name) {
  final file = File('$_fixturesDir/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('packages/contracts fixture parity', () {
    test('catalog.v1.json parses with CatalogResponse', () {
      final json = _readFixture('catalog.v1.json');
      final response = CatalogResponse.fromJson(json);

      expect(response.schemaVersion, '1.0');
      expect(response.featuredSlug, 'gece-denemesi');
      expect(response.series, hasLength(1));

      final series = response.series.single;
      expect(series.metadata.slug, 'gece-denemesi');
      expect(series.metadata.title, 'Gece Denemesi');
      expect(series.metadata.status, 'Devam Ediyor');
      expect(series.metadata.genres, ['Gizem', 'Romantik']);
      expect(series.metadata.rating, 4.5);
      expect(series.metadata.isNew, isTrue);
      expect(series.metadata.coverImage, '/images/gece-denemesi.webp');
      expect(series.episodeCount, 1);
      expect(series.latestEpisode?.slug, 'bolum-1');
      expect(series.latestEpisode?.panels, hasLength(1));
      expect(series.latestEpisode?.panels.single.tone, PanelTone.blue);
    });

    test('series-detail.v1.json parses with SeriesDetailResponse', () {
      final json = _readFixture('series-detail.v1.json');
      final response = SeriesDetailResponse.fromJson(json);

      expect(response.schemaVersion, '1.0');
      expect(response.series.slug, 'gece-denemesi');
      expect(response.series.genres, ['Gizem', 'Romantik']);
      expect(response.series.coverImage, '/images/gece-denemesi.webp');
      expect(response.episodes, hasLength(1));
      expect(response.episodes.single.slug, 'bolum-1');
      expect(response.episodes.single.panelCount, 1);
    });

    test('episode-manifest.v1.json parses with EpisodeManifestResponse', () {
      final json = _readFixture('episode-manifest.v1.json');
      final response = EpisodeManifestResponse.fromJson(json);

      expect(response.schemaVersion, '1.0');
      expect(response.series.slug, 'gece-denemesi');
      expect(response.series.title, 'Gece Denemesi');
      expect(response.episode.panels, hasLength(1));

      final panel = response.episode.panels.single;
      expect(panel.image?.src, '/images/gece-denemesi/panel-1.webp');
      expect(panel.image?.width, 1080);
      expect(panel.align, 'left');
      expect(panel.tone, PanelTone.blue);

      expect(response.previous, isNull);
      expect(response.next?.slug, 'bolum-2');
      expect(response.next?.number, 2);
    });
  });
}
