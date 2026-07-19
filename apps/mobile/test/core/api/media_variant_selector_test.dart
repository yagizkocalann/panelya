import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/core/api/media_variant_selector.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';

PublicMediaVariant _variant(int width, {int height = 0}) {
  return PublicMediaVariant(
    src: '/api/media/fixture?width=$width',
    width: width,
    height: height == 0 ? (width * 4 / 3).round() : height,
    mimeType: 'image/webp',
  );
}

void main() {
  group('selectMediaVariant', () {
    test('null/boş liste için null döner (çağıran src geri-düşüşüne düşer)', () {
      expect(selectMediaVariant(null, 480), isNull);
      expect(selectMediaVariant(const [], 480), isNull);
    });

    test('tam eşleşen genişlik varsa onu döner', () {
      final variants = [_variant(480), _variant(768), _variant(1080)];
      expect(selectMediaVariant(variants, 768), same(variants[1]));
    });

    test(
      'aradaki hedef genişlik için ihtiyacı karşılayan en küçük varyant '
      'seçilir (fazla büyük varyant indirilmez)',
      () {
        final variants = [_variant(480), _variant(768), _variant(1080)];
        // 600px hedef: 480 yetersiz, 768 yeterli ve en küçüğü -> 768 seçilir.
        expect(selectMediaVariant(variants, 600), same(variants[1]));
      },
    );

    test(
      'hepsi hedeften küçükse (hiçbiri ihtiyacı karşılamıyorsa) en büyük '
      'varyant seçilir',
      () {
        final variants = [_variant(480), _variant(768)];
        expect(selectMediaVariant(variants, 2000), same(variants[1]));
      },
    );

    test('sırasız (azalan) liste doğru sonucu verir', () {
      final variants = [_variant(1080), _variant(480), _variant(768)];
      expect(selectMediaVariant(variants, 600)?.width, 768);
      expect(selectMediaVariant(variants, 2000)?.width, 1080);
      expect(selectMediaVariant(variants, 100)?.width, 480);
    });

    test('tek elemanlı liste her zaman o elemanı döner', () {
      final variant = _variant(480);
      expect(selectMediaVariant([variant], 100), same(variant));
      expect(selectMediaVariant([variant], 2000), same(variant));
    });

    test(
      'packages/contracts fixture değerleriyle entegrasyon: gerçek '
      '480/768 varyant genişlikleri ve DPR ile hesaplanmış hedeflerde '
      'beklenen varyant seçilir',
      () {
        // Bkz. packages/contracts/fixtures/catalog.v1.json /
        // series-detail.v1.json `coverImageVariants` ve
        // episode-manifest.v1.json panel `image.variants` — ikisi de
        // [480, 768] genişlik kümesi kullanır.
        final variants = [_variant(480), _variant(768)];

        // 360 mantıksal px kolon genişliği × 1.0 DPR = 360px hedef.
        expect(selectMediaVariant(variants, 360 * 1.0)?.width, 480);
        // Aynı kolon × 2.0 DPR (yaygın telefon) = 720px hedef -> 768 yeterli
        // ve en küçüğü.
        expect(selectMediaVariant(variants, 360 * 2.0)?.width, 768);
        // 3.0 DPR = 1080px hedef; hiçbir varyant yeterli değil -> en büyüğü
        // (768) döner.
        expect(selectMediaVariant(variants, 360 * 3.0)?.width, 768);
      },
    );
  });
}
