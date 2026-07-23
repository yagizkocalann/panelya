import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';

/// Bu testler `packages/contracts/fixtures/` altındaki SALT OKUNUR, ortak
/// (main'den `codex/mobile`'a merge edilen) sentetik fixture'ları dosya
/// sisteminden okuyup `lib/core/contracts/generated/` altındaki,
/// `tool/generate_contracts.dart` tarafından `packages/contracts/
/// schema.json`'dan üretilen DTO'larla ayrıştırır. Fixture içerikleri
/// buraya kopyalanmaz; `packages/contracts/` tek doğruluk kaynağı olarak
/// kalır (bkz. packages/contracts/README.md "Değişiklik kuralı"). Bu paket
/// dosyalarına buradan YAZILMAZ.
///
/// Geçici elle yazılmış adapter (`lib/core/contracts/*.dart`, `generated/`
/// hariç) ortak sözleşme kaynağı `main`'e gelip codegen kurulduktan sonra
/// kaldırıldı (bkz. docs/mobile-handoff.md Ortaklık kuralları #3); bu
/// yüzden burada artık yalnız üretilen DTO'lar test edilir, ayrı bir
/// "eski adapter" grubu yoktur.
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
  group('packages/contracts fixture parity (generated DTOs)', () {
    test('catalog.v1.json parses with generated CatalogResponse', () {
      final json = _readFixture('catalog.v1.json');
      final response = CatalogResponse.fromJson(json);

      expect(response.schemaVersion, '1.0');
      expect(response.featuredSlug, 'gece-denemesi');
      expect(response.series, hasLength(1));

      final series = response.series.single;
      expect(series.slug, 'gece-denemesi');
      expect(series.title, 'Gece Denemesi');
      expect(series.status, 'Devam Ediyor');
      expect(series.genres, ['Gizem', 'Romantik']);
      expect(series.rating, 4.5);
      expect(series.isNew, isTrue);
      expect(series.coverImage, '/api/media/fixture-cover-1');
      expect(series.coverImageVariants, hasLength(2));
      expect(series.coverImageVariants?.first.width, 480);
      expect(series.coverImageVariants?.first.height, 640);
      expect(series.coverImageVariants?.first.mimeType, 'image/webp');
      expect(series.episodeCount, 1);
      expect(series.latestEpisode?.slug, 'bolum-1');
      expect(series.latestEpisode?.panels, hasLength(1));
      expect(series.latestEpisode?.panels.single.tone, PanelTone.blue);

      // Round-trip: toJson() sonucu aynı fixture ile yeniden ayrıştırılabilir
      // olmalı (byte-eşitlik değil, semantik eşitlik). Fixture yalnız bilinen
      // enum değerleri kullandığı için LENIENT `unknown` fallback'i burada
      // hiç tetiklenmez.
      final roundTripped = CatalogResponse.fromJson(response.toJson());
      expect(roundTripped.series.single.slug, series.slug);
    });

    test(
      'series-detail.v1.json parses with generated SeriesDetailResponse',
      () {
        final json = _readFixture('series-detail.v1.json');
        final response = SeriesDetailResponse.fromJson(json);

        expect(response.schemaVersion, '1.0');
        expect(response.series.slug, 'gece-denemesi');
        expect(response.series.genres, ['Gizem', 'Romantik']);
        expect(response.series.coverImage, '/api/media/fixture-cover-1');
        expect(response.series.coverImageVariants, hasLength(2));
        expect(response.episodes, hasLength(1));
        expect(response.episodes.single.slug, 'bolum-1');
        expect(response.episodes.single.panelCount, 1);

        final roundTripped = SeriesDetailResponse.fromJson(response.toJson());
        expect(roundTripped.series.slug, response.series.slug);
      },
    );

    test(
      'episode-manifest.v1.json parses with generated '
      'EpisodeManifestResponse',
      () {
        final json = _readFixture('episode-manifest.v1.json');
        final response = EpisodeManifestResponse.fromJson(json);

        expect(response.schemaVersion, '1.0');
        expect(response.series.slug, 'gece-denemesi');
        expect(response.series.title, 'Gece Denemesi');
        expect(response.episode.panels, hasLength(1));

        final panel = response.episode.panels.single;
        expect(panel.image?.src, '/api/media/fixture-panel-1');
        expect(panel.image?.width, 1080);
        expect(panel.image?.variants, hasLength(2));
        expect(
          panel.image?.variants?.first.src,
          '/api/media/fixture-panel-1?width=480',
        );
        expect(panel.image?.variants?.first.width, 480);
        expect(panel.align, 'left');
        expect(panel.tone, PanelTone.blue);

        expect(response.navigation.previous, isNull);
        expect(response.navigation.next?.slug, 'bolum-2');
        expect(response.navigation.next?.number, 2);

        final roundTripped = EpisodeManifestResponse.fromJson(
          response.toJson(),
        );
        expect(roundTripped.episode.slug, response.episode.slug);
      },
    );

    test('discovery.v1.json parses with generated DiscoveryResponse', () {
      final json = _readFixture('discovery.v1.json');
      final response = DiscoveryResponse.fromJson(json);

      expect(response.schemaVersion, '1.0');
      expect(response.featuredSeries?.slug, 'gece-denemesi');
      expect(response.featuredSeries?.genres, ['Gizem', 'Romantik']);
      expect(response.featuredFirstEpisode?.slug, 'bolum-1');
      expect(response.featuredFirstEpisode?.number, 1);
      expect(response.genres, ['Gizem', 'Romantik']);
      expect(response.newSeries, hasLength(1));
      expect(response.newSeries.single.slug, 'gece-denemesi');
      expect(response.newSeries.single.coverImageVariants, hasLength(1));
      expect(response.latestEpisodes, hasLength(1));
      expect(response.latestEpisodes.single.series.slug, 'gece-denemesi');
      expect(response.latestEpisodes.single.episode.slug, 'bolum-1');

      final roundTripped = DiscoveryResponse.fromJson(response.toJson());
      expect(roundTripped.newSeries.single.slug, response.newSeries.single.slug);
    });

    test(
      'unknown PanelTone value falls back to PanelTone.unknown '
      '(LENIENT enum policy) instead of throwing',
      () {
        final json = _readFixture('catalog.v1.json');
        final mutable = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
        final firstSeries = (mutable['series'] as List).first as Map<String, dynamic>;
        final latestEpisode = firstSeries['latestEpisode'] as Map<String, dynamic>;
        final firstPanel = (latestEpisode['panels'] as List).first as Map<String, dynamic>;
        firstPanel['tone'] = 'a-brand-new-tone-the-client-has-never-seen';

        final response = CatalogResponse.fromJson(mutable);
        final tone = response.series.single.latestEpisode!.panels.single.tone;

        expect(tone, PanelTone.unknown);
        expect(() => tone.toJson(), throwsUnsupportedError);
      },
    );
  });
}
