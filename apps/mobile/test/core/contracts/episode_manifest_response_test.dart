import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/core/contracts/episode_manifest_response.dart';

/// `GET /api/series/:slug/episodes/:episodeSlug` fixture'ı —
/// `app/api/series/[slug]/episodes/[episode]/route.ts`'nin gerçek şeklini
/// birebir yansıtır: üst seviye `series` yalnız `{slug, title}`, `episode`
/// tam (panels dahil), `navigation.previous/next` `{slug, number} | null`.
Map<String, dynamic> _manifestJson({
  Map<String, dynamic>? previous,
  Map<String, dynamic>? next,
}) => {
  'schemaVersion': '1.0',
  'series': {'slug': 'gece-vardiyasi', 'title': 'Gece Vardiyası'},
  'episode': {
    'slug': 'bolum-2',
    'number': 2,
    'title': 'Yarınki Adres',
    'publishedAt': '12 Temmuz 2026',
    'readTime': '8 dk',
    'panels': [
      {
        'id': 'yarinki-adres-opening',
        'scene': 'Yarınki Adres için atmosferik açılış karesi.',
        'caption': 'Yeni bir hikâye başlıyor.',
        'tone': 'mint',
      },
      {
        'id': 'yarinki-adres-hook',
        'scene': 'Yarınki Adres kahramanının karar anı.',
        'dialogue': 'Geri dönüş yok.',
        'tone': 'mint',
        'align': 'right',
      },
    ],
  },
  'navigation': {'previous': previous, 'next': next},
};

void main() {
  group('EpisodeManifestResponse.fromJson', () {
    test('parses series ref, full episode with panels and navigation', () {
      final response = EpisodeManifestResponse.fromJson(
        _manifestJson(
          previous: {'slug': 'bolum-1', 'number': 1},
          next: {'slug': 'bolum-3', 'number': 3},
        ),
      );

      expect(response.schemaVersion, '1.0');
      expect(response.series.slug, 'gece-vardiyasi');
      expect(response.series.title, 'Gece Vardiyası');

      expect(response.episode.slug, 'bolum-2');
      expect(response.episode.panels, hasLength(2));
      expect(response.episode.panels.last.dialogue, 'Geri dönüş yok.');
      expect(response.episode.panels.last.align, 'right');

      expect(response.previous, isNotNull);
      expect(response.previous!.slug, 'bolum-1');
      expect(response.next, isNotNull);
      expect(response.next!.number, 3);
    });

    test('previous/next are null at the ends of a series', () {
      final response = EpisodeManifestResponse.fromJson(
        _manifestJson(previous: null, next: null),
      );

      expect(response.previous, isNull);
      expect(response.next, isNull);
    });
  });
}
