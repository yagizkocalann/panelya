import '../../../core/contracts/generated/generated.dart';

/// Kütüphane/favori sözleşmesi (bkz. ADR-048, OpenAPI 1.5.0).
///
/// SIRALAMA: [fetchLibrary] sunucunun verdiği sırayı OLDUĞU GİBİ korur.
/// İstemci `updatedAt` damgasından ya da Türkçe gösterim metninden
/// (`series.updatedAt` — "Yeni bölüm" gibi insan okunur bir etiket)
/// yeniden sıralama ÜRETMEZ.
///
/// Kimlik: mobil istemci yalnız `Authorization: Bearer` kullanır. Web'in
/// cookie oturumu ya da form gönderim mantığı KOPYALANMAZ.
abstract class LibraryRepository {
  /// `GET /api/library`
  Future<LibraryResponse> fetchLibrary();

  /// `POST /api/library/{slug}` — ekleme/güncelleme.
  ///
  /// Gövde TOGGLE DEĞİLDİR: hedef durumun TAMAMI gönderilir. Çağıran, hem
  /// [status] hem [favorite] için istenen SON değeri verir; sunucu
  /// mevcut değeri tersine çevirmez.
  Future<LibraryMutationResponse> upsertEntry({
    required String slug,
    required LibraryStatus status,
    required bool favorite,
  });

  /// `DELETE /api/library/{slug}` — kütüphaneden çıkarma.
  ///
  /// IDEMPOTENTTIR: kayıt zaten yoksa sunucu `removed: false` ile başarılı
  /// döner. Bu bir HATA DEĞİLDİR ve çağıran tarafından hata gibi
  /// gösterilmemelidir.
  Future<LibraryRemovalResponse> removeEntry(String slug);
}
