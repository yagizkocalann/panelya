import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';

/// `packages/contracts/fixtures/reading-progress-*.v1.json` (SALT OKUNUR)
/// ile üretilen `reading_progress_*.dart` DTO'larının ayrıştırma uyumu.
///
/// Fixture içerikleri KOPYALANMAZ; her test dosyayı doğrudan okur.
const _fixturesDir = '../../packages/contracts/fixtures';

Map<String, dynamic> _readFixture(String name) =>
    jsonDecode(File('$_fixturesDir/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('packages/contracts reading-progress fixture parity', () {
    test('4 ilerleme fixture dosyasının tamamı diskte mevcut', () {
      final files = Directory(_fixturesDir)
          .listSync()
          .whereType<File>()
          .map((file) => file.uri.pathSegments.last)
          .where((name) => name.startsWith('reading-progress-'))
          .toList();
      expect(files, hasLength(4));
    });

    test('reading-progress-response.v1.json -> ReadingProgressResponse', () {
      final response = ReadingProgressResponse.fromJson(
        _readFixture('reading-progress-response.v1.json'),
      );

      expect(response.schemaVersion, kSchemaVersion);
      expect(response.items, hasLength(1));

      final item = response.items.single;
      expect(item.percent, 64);
      expect(item.updatedAt, '2026-08-02T11:45:00.000Z');
      // Mevcut DTO'lar yeniden kullanılır — ilerlemeye özel seri/bölüm
      // modeli TÜRETİLMEZ.
      expect(item.series.slug, 'gece-vardiyasi');
      expect(item.episode.slug, 'bolum-2');
      expect(item.episode.number, 2);
    });

    test('reading-progress-mutation-response.v1.json -> '
        'ReadingProgressMutationResponse', () {
      final response = ReadingProgressMutationResponse.fromJson(
        _readFixture('reading-progress-mutation-response.v1.json'),
      );

      expect(response.schemaVersion, kSchemaVersion);
      expect(response.item.percent, 64);
      expect(response.item.episode.slug, 'bolum-2');
    });

    test('reading-progress-upsert-request.v1.json -> istek gövdesi', () {
      final fixture = _readFixture('reading-progress-upsert-request.v1.json');
      final request = ReadingProgressUpsertRequest.fromJson(fixture);

      expect(request.seriesSlug, 'gece-vardiyasi');
      expect(request.episodeSlug, 'bolum-2');
      expect(request.percent, 64);
      // Gövde TOGGLE/DELTA değil, hedef durumun tamamı — üretilen JSON
      // fixture ile birebir aynı olmalı.
      expect(request.toJson(), fixture);
    });

    test('reading-progress-error.v1.json -> ReadingProgressErrorResponse', () {
      final response = ReadingProgressErrorResponse.fromJson(
        _readFixture('reading-progress-error.v1.json'),
      );

      expect(response.schemaVersion, kSchemaVersion);
      expect(response.error, 'not_authenticated');
      expect(response.errorDescription, 'Bu işlem için giriş yapmalısın.');
    });
  });
}
