import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/shared/utils/turkish_search.dart';

void main() {
  group('normalizeCatalogSearch (Türkçe katalog arama normalizasyonu)', () {
    // bkz. `app/lib/content-repository.ts` -> `normalizeCatalogSearch` (web
    // referansı, SALT OKUNUR); bu testler Dart portunun aynı pratik sonucu
    // ürettiğini doğrular (bkz. `lib/shared/utils/turkish_search.dart` doc
    // yorumundaki "NFKD sapması" notu).

    test('is idempotent on already-normalized ascii lowercase text', () {
      expect(normalizeCatalogSearch('gece vardiyasi'), 'gece vardiyasi');
    });

    test('Turkish dotted capital İ folds to plain i, matching lowercase input', () {
      expect(normalizeCatalogSearch('İstanbul'), normalizeCatalogSearch('istanbul'));
      expect(normalizeCatalogSearch('İstanbul'), 'istanbul');
    });

    test('Turkish dotless ı folds to i (ışık ~ isik)', () {
      expect(normalizeCatalogSearch('ışık'), 'isik');
      expect(normalizeCatalogSearch('ışık'), normalizeCatalogSearch('isik'));
    });

    test('plain ascii capital I also folds down to i (case-insensitive)', () {
      expect(normalizeCatalogSearch('Istanbul'), normalizeCatalogSearch('istanbul'));
    });

    test('Turkish ç/ğ/ş/ö/ü fold to their base ascii letters', () {
      expect(normalizeCatalogSearch('Çılgın Şoför Öğretmen Ürün'),
          'cilgin sofor ogretmen urun');
    });

    test('generic Latin-1 accents fold to their base ascii letters', () {
      expect(normalizeCatalogSearch('café résumé'), 'cafe resume');
      expect(normalizeCatalogSearch('naïve'), 'naive');
    });

    test('non-alphanumeric runs collapse to a single space and are trimmed', () {
      expect(normalizeCatalogSearch('  Gece -- Vardiyası!!  '), 'gece vardiyasi');
      expect(normalizeCatalogSearch('bölüm#1'), 'bolum 1');
    });

    test('digits are preserved', () {
      expect(normalizeCatalogSearch('Bölüm 12'), 'bolum 12');
    });

    test('empty and whitespace-only input normalizes to an empty string', () {
      expect(normalizeCatalogSearch(''), '');
      expect(normalizeCatalogSearch('   '), '');
    });

    test(
      'a normalized query is found as a substring of a longer normalized '
      'catalog haystack (phrase match, not independent word AND/OR — bkz. '
      'docs/mobile-handoff.md madde 7)',
      () {
        final haystack = normalizeCatalogSearch(
          'Gece Vardiyası: Kayıp Dakikanın İzinde — Gizem, Dram',
        );
        expect(haystack.contains(normalizeCatalogSearch('kayıp dakikanın')), isTrue);
        expect(haystack.contains(normalizeCatalogSearch('KAYIP DAKIKANIN')), isTrue);
        // Kelime sırası değişince (bağımsız kelime eşleşmesi DEĞİL, ifade
        // eşleşmesi olduğu için) artık geçmemeli.
        expect(haystack.contains(normalizeCatalogSearch('dakikanın kayıp')), isFalse);
      },
    );
  });
}
