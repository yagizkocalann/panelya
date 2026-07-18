import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/core/contracts/catalog_response.dart';
import 'package:panelya_mobile/core/contracts/schema_version.dart';
import 'package:panelya_mobile/core/contracts/story_panel.dart';

/// `GET /api/catalog` fixture'ı — `app/api/catalog/route.ts` ve
/// `app/data/catalog.ts`'teki gerçek şekli birebir yansıtır:
/// `{ schemaVersion, featuredSlug, series: [{ ...series, episodeCount,
/// latestEpisode }] }`.
Map<String, dynamic> _catalogJson() => {
  'schemaVersion': '1.0',
  'featuredSlug': 'gece-vardiyasi',
  'series': [
    {
      'slug': 'gece-vardiyasi',
      'title': 'Gece Vardiyası',
      'eyebrow': 'Zamanı geri saran bir teslimat',
      'creator': 'Panelya Originals',
      'description': 'Gece kuryesi Ece...',
      'longDescription': 'Ece için gece vardiyası...',
      'status': 'Devam Ediyor',
      'genres': ['Gizem', 'Bilim Kurgu', 'Dram'],
      'tone': 'coral',
      'updatedAt': 'Bugün',
      'rating': 4.9,
      'followers': '12,8 B',
      'episodeCount': 3,
      'latestEpisode': {
        'slug': 'bolum-3',
        'number': 3,
        'title': 'Kayıp Dakika',
        'publishedAt': '18 Temmuz 2026',
        'readTime': '7 dk',
        'panels': [
          {
            'id': 'kayip-dakika-opening',
            'scene': 'Kayıp Dakika için atmosferik açılış karesi.',
            'caption': 'Yeni bir hikâye başlıyor.',
            'tone': 'violet',
          },
        ],
      },
    },
    {
      'slug': 'yarinki-ses',
      'title': 'Yarınki Ses',
      'eyebrow': 'Yarından gelen bir kayıt',
      'creator': 'Panelya Originals · Özgün Görsel Pilot',
      'description': 'Ses tasarımı öğrencisi Derya...',
      'longDescription': 'Derya için sesler...',
      'status': 'Devam Ediyor',
      'genres': ['Romantizm', 'Gizem', 'Dram'],
      'tone': 'blue',
      'updatedAt': 'Bugün',
      'rating': 0,
      'followers': 'Yeni',
      'isNew': true,
      'coverImage': '/images/yarinki-ses/panel-017-mode-b-v1-clean.webp',
      'coverPosition': '50% 34%',
      'episodeCount': 1,
      'latestEpisode': {
        'slug': 'bolum-1',
        'number': 1,
        'title': 'Kayıtta Ben Varım',
        'publishedAt': '18 Temmuz 2026',
        'readTime': '8 dk',
        'panels': [
          {
            'id': 'tomorrow-voice-01',
            'scene': 'Gece ses laboratuvarında Derya...',
            'caption': 'Kayıttaki Derya · yarın',
            'dialogue': 'Baran… bu kez gelme.',
            'tone': 'blue',
            'image': {
              'src': '/images/yarinki-ses/panel-001-mode-b-v1-clean.webp',
              'alt': 'Karanlık ses laboratuvarında kulaklıkla kayıt dinleyen Derya.',
              'width': 972,
              'height': 1619,
            },
          },
        ],
      },
    },
  ],
};

void main() {
  group('CatalogResponse.fromJson', () {
    test('parses schemaVersion, featuredSlug and series list', () {
      final response = CatalogResponse.fromJson(_catalogJson());

      expect(response.schemaVersion, '1.0');
      expect(response.featuredSlug, 'gece-vardiyasi');
      expect(response.series, hasLength(2));
    });

    test('parses full series summary fields including nullable ones', () {
      final response = CatalogResponse.fromJson(_catalogJson());
      final first = response.series.first;

      expect(first.metadata.slug, 'gece-vardiyasi');
      expect(first.metadata.title, 'Gece Vardiyası');
      expect(first.metadata.status, 'Devam Ediyor');
      expect(first.metadata.genres, ['Gizem', 'Bilim Kurgu', 'Dram']);
      expect(first.metadata.rating, 4.9);
      expect(first.metadata.isNew, isNull);
      expect(first.metadata.coverImage, isNull);
      expect(first.episodeCount, 3);
      expect(first.latestEpisode, isNotNull);
      expect(first.latestEpisode!.slug, 'bolum-3');
      expect(first.latestEpisode!.number, 3);
      expect(first.latestEpisode!.panels, hasLength(1));
      expect(first.latestEpisode!.panels.single.tone, PanelTone.violet);
    });

    test('parses optional isNew/coverImage/coverPosition and panel image', () {
      final response = CatalogResponse.fromJson(_catalogJson());
      final second = response.series[1];

      expect(second.metadata.isNew, isTrue);
      expect(
        second.metadata.coverImage,
        '/images/yarinki-ses/panel-017-mode-b-v1-clean.webp',
      );
      expect(second.metadata.coverPosition, '50% 34%');
      expect(second.metadata.rating, 0);

      final panel = second.latestEpisode!.panels.single;
      expect(panel.dialogue, 'Baran… bu kez gelme.');
      expect(panel.image, isNotNull);
      expect(panel.image!.width, 972);
      expect(panel.image!.height, 1619);
      expect(panel.tone, PanelTone.blue);
    });

    test('featuredSlug can be null (empty catalog)', () {
      final json = _catalogJson();
      json['featuredSlug'] = null;
      json['series'] = <dynamic>[];

      final response = CatalogResponse.fromJson(json);

      expect(response.featuredSlug, isNull);
      expect(response.series, isEmpty);
    });

    test('throws SchemaVersionMismatchException on unsupported schemaVersion', () {
      final json = _catalogJson();
      json['schemaVersion'] = '2.0';

      expect(
        () => CatalogResponse.fromJson(json),
        throwsA(isA<SchemaVersionMismatchException>()),
      );
    });
  });
}
