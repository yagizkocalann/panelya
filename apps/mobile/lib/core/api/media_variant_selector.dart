import '../contracts/generated/generated.dart';

/// Ortak sözleşme v1.2 ile gelen `PublicMediaVariant` listeleri
/// (`SeriesSummary.coverImageVariants`, `SeriesMetadata.coverImageVariants`,
/// `StoryPanelImage.variants`, bkz. `lib/core/contracts/generated/`) için saf
/// seçim fonksiyonu. Ağ isteği, widget veya API client katmanına dokunmaz —
/// yalnız bir liste ve bir hedef genişlik alıp bir [PublicMediaVariant]?
/// döner (bkz. widget/unit testleri: `test/core/api/media_variant_selector_test.dart`).
///
/// [targetWidthPx], çağıranın hesapladığı GERÇEK piksel genişliğidir
/// (mantıksal görüntüleme genişliği × cihaz piksel oranı — `devicePixelRatio`).
/// Bu fonksiyon DPR'ı kendisi uygulamaz; çarpım çağıran tarafından (bkz.
/// `CoverImage`, `reader_screen.dart` `_PanelBlock`) yapılır ki bu dosya
/// Flutter'a (`dart:ui`/`MediaQuery`) bağımlı kalmasın ve saf birim
/// testleriyle doğrulanabilsin.
///
/// Seçim kuralı: ihtiyacı GEREKSİZ AŞMAYAN en uygun varyant — hedefi
/// karşılayan (`variant.width >= targetWidthPx`) varyantlar arasından en
/// KÜÇÜK genişlikli olan seçilir (gereksiz büyük bir dosya indirilmez).
/// Hiçbir varyant hedefi karşılamıyorsa (hepsi hedeften küçükse) elde
/// olanın en iyisi olarak en BÜYÜK genişlikli varyant seçilir (küçük/
/// bulanık bir görsel yerine). `variants` `null` veya boşsa `null` döner;
/// çağıran yer bu durumda mevcut `src`/`coverImage` geri-düşüş alanına
/// düşer — bu geri-düşüş yolu, varyant döndürmeyen canlı yerel API için
/// zaten tek çalışan yoldur (bkz. görev bağlamı).
///
/// Liste sırası önemli değildir; sıralı olmayan bir varyant listesi de
/// doğru sonucu verir (tüm liste taranır, ilk eşleşende durulmaz).
PublicMediaVariant? selectMediaVariant(
  List<PublicMediaVariant>? variants,
  double targetWidthPx,
) {
  if (variants == null || variants.isEmpty) return null;

  PublicMediaVariant? smallestSufficient;
  var largest = variants.first;

  for (final variant in variants) {
    if (variant.width > largest.width) {
      largest = variant;
    }
    if (variant.width >= targetWidthPx &&
        (smallestSufficient == null ||
            variant.width < smallestSufficient.width)) {
      smallestSufficient = variant;
    }
  }

  return smallestSufficient ?? largest;
}
