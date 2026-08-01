import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';

/// `packages/contracts/fixtures/library-*.v1.json` (SALT OKUNUR, ortak
/// sentetik fixture'lar, bkz. ADR-048 / OpenAPI 1.5.0) ile
/// `lib/core/contracts/generated/library_*.dart` DTO'larının ayrıştırma
/// uyumunu doğrular.
///
/// Fixture içerikleri buraya KOPYALANMAZ — her test dosyayı doğrudan okur
/// (bkz. `account_fixture_contracts_test.dart` ile aynı desen). Böylece web
/// tarafı bir fixture'ı güncellediğinde bu testler gerçekten kırılır;
/// sabitlenmiş bir kopya sessizce eskimez.
const _fixturesDir = '../../packages/contracts/fixtures';

Map<String, dynamic> _readFixture(String name) {
  final file = File('$_fixturesDir/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('packages/contracts library fixture parity (generated DTOs)', () {
    test('5 kütüphane fixture dosyasının tamamı diskte mevcut', () {
      final files = Directory(_fixturesDir)
          .listSync()
          .whereType<File>()
          .map((file) => file.uri.pathSegments.last)
          .where((name) => name.startsWith('library-'))
          .toList();
      // Yeni bir fixture eklenirse bu test KASITLI olarak kırılır ve buraya
      // bir parser testi eklenmesi gerektiğini hatırlatır.
      expect(files, hasLength(5));
    });

    test('library-response.v1.json -> LibraryResponse', () {
      final response = LibraryResponse.fromJson(
        _readFixture('library-response.v1.json'),
      );

      expect(response.schemaVersion, kSchemaVersion);
      expect(response.items, hasLength(1));

      final item = response.items.single;
      expect(item.status, LibraryStatus.reading);
      expect(item.favorite, isTrue);
      // Sunucu sıralaması için kullanılan ISO-8601 UTC damgası; istemci
      // bunu YENİDEN SIRALAMA için kullanmaz (bkz. `LibraryRepository`).
      expect(item.updatedAt, '2026-08-02T10:30:00.000Z');

      // `series` mevcut `DiscoverySeriesSummary` DTO'sunu yeniden kullanır —
      // kütüphaneye özel bir seri modeli TÜRETİLMEZ.
      expect(item.series.slug, 'gece-vardiyasi');
      expect(item.series.episodeCount, 3);
      // Responsive medya varyantları kart görselinde yeniden kullanılır.
      expect(item.series.coverImageVariants, hasLength(1));
      expect(item.series.coverImageVariants!.single.width, 480);
    });

    test('library-mutation-response.v1.json -> LibraryMutationResponse', () {
      final response = LibraryMutationResponse.fromJson(
        _readFixture('library-mutation-response.v1.json'),
      );

      expect(response.schemaVersion, kSchemaVersion);
      expect(response.item.status, LibraryStatus.reading);
      expect(response.item.favorite, isTrue);
      expect(response.item.series.slug, 'gece-vardiyasi');
    });

    test('library-removal-response.v1.json -> LibraryRemovalResponse', () {
      final response = LibraryRemovalResponse.fromJson(
        _readFixture('library-removal-response.v1.json'),
      );

      expect(response.schemaVersion, kSchemaVersion);
      expect(response.removed, isTrue);
    });

    test('library-upsert-request.v1.json -> LibraryUpsertRequest', () {
      final fixture = _readFixture('library-upsert-request.v1.json');
      final request = LibraryUpsertRequest.fromJson(fixture);

      expect(request.status, LibraryStatus.reading);
      expect(request.favorite, isTrue);
      // Gövde TOGGLE değildir: hedef durumun TAMAMI gönderilir. Üretilen
      // JSON fixture ile birebir aynı olmalı.
      expect(request.toJson(), fixture);
    });

    test('library-error.v1.json -> LibraryErrorResponse', () {
      final response = LibraryErrorResponse.fromJson(
        _readFixture('library-error.v1.json'),
      );

      expect(response.schemaVersion, kSchemaVersion);
      // Üretilen DTO `error` alanını String tutar (bkz.
      // `AccountErrorResponse` ile aynı desen); enum TÜRETİLMEZ.
      expect(response.error, 'not_authenticated');
      expect(response.errorDescription, 'Bu işlem için giriş yapmalısın.');
    });

    test('LibraryStatus enum sözleşmedeki BEŞ değerin tamamını tanır ve '
        'bilinmeyen bir değeri ileri-uyumluluk fallback\'ine düşürür', () {
      expect(LibraryStatus.fromJson('plan'), LibraryStatus.plan);
      expect(LibraryStatus.fromJson('reading'), LibraryStatus.reading);
      expect(LibraryStatus.fromJson('completed'), LibraryStatus.completed);
      expect(LibraryStatus.fromJson('paused'), LibraryStatus.paused);
      expect(LibraryStatus.fromJson('dropped'), LibraryStatus.dropped);
      // Sunucu ileride yeni bir durum eklerse istemci ÇÖKMEZ; yanlış bir
      // durum da UYDURMAZ.
      expect(
        LibraryStatus.fromJson('gelecekte-eklenen-durum'),
        LibraryStatus.unknown,
      );
    });
  });
}
