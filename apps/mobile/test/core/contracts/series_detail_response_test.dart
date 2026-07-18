import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/core/contracts/schema_version.dart';
import 'package:panelya_mobile/core/contracts/series_detail_response.dart';

/// `GET /api/series/:slug` fixture'ı — `app/api/series/[slug]/route.ts`'nin
/// gerçek şeklini birebir yansıtır: `episodes[]` içinde `panels` düşürülmüş,
/// yerine `panelCount` eklenmiştir.
Map<String, dynamic> _seriesDetailJson() => {
  'schemaVersion': '1.0',
  'series': {
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
  },
  'episodes': [
    {
      'slug': 'bolum-3',
      'number': 3,
      'title': 'Kayıp Dakika',
      'publishedAt': '18 Temmuz 2026',
      'readTime': '7 dk',
      'panelCount': 2,
    },
    {
      'slug': 'bolum-2',
      'number': 2,
      'title': 'Yarınki Adres',
      'publishedAt': '12 Temmuz 2026',
      'readTime': '8 dk',
      'panelCount': 2,
    },
    {
      'slug': 'bolum-1',
      'number': 1,
      'title': 'Son Teslimat',
      'publishedAt': '5 Temmuz 2026',
      'readTime': '9 dk',
      'panelCount': 7,
    },
  ],
};

void main() {
  group('SeriesDetailResponse.fromJson', () {
    test('parses series metadata without an episodes field', () {
      final response = SeriesDetailResponse.fromJson(_seriesDetailJson());

      expect(response.schemaVersion, '1.0');
      expect(response.series.slug, 'gece-vardiyasi');
      expect(response.series.title, 'Gece Vardiyası');
      expect(response.series.isCompleted, isFalse);
    });

    test('parses episodes with panelCount instead of panels', () {
      final response = SeriesDetailResponse.fromJson(_seriesDetailJson());

      expect(response.episodes, hasLength(3));
      expect(response.episodes.first.slug, 'bolum-3');
      expect(response.episodes.first.panelCount, 2);
      expect(response.episodes.last.number, 1);
      expect(response.episodes.last.panelCount, 7);
    });

    test('isCompleted reflects "Tamamlandı" status', () {
      final json = _seriesDetailJson();
      (json['series'] as Map<String, dynamic>)['status'] = 'Tamamlandı';

      final response = SeriesDetailResponse.fromJson(json);

      expect(response.series.isCompleted, isTrue);
    });

    test('throws SchemaVersionMismatchException when schemaVersion is missing', () {
      final json = _seriesDetailJson();
      json.remove('schemaVersion');

      expect(
        () => SeriesDetailResponse.fromJson(json),
        throwsA(isA<SchemaVersionMismatchException>()),
      );
    });
  });
}
