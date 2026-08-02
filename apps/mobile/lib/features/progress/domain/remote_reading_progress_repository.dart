import '../../../core/contracts/generated/generated.dart';

/// Ortak okuma ilerlemesi sözleşmesi (bkz. `packages/contracts`,
/// OpenAPI 1.6.0).
///
/// Mevcut cihaz-yerel [LocalReadingProgressRepository] KORUNUR ve bunun
/// yerine geçmez: anonim kullanıcı ve çevrimdışı okuma tamamen yerel
/// kayıtla çalışmaya devam eder.
///
/// Mobil kimlik YALNIZ `Authorization: Bearer` ile taşınır; web'in cookie
/// oturumu veya `localStorage` anahtarı KOPYALANMAZ.
abstract class RemoteReadingProgressRepository {
  /// `GET /api/progress` — sunucunun SIRASI korunur.
  Future<ReadingProgressResponse> fetchProgress();

  /// `POST /api/progress`.
  ///
  /// TOGGLE veya DELTA DEĞİLDİR: hedef durumun tamamı gönderilir.
  /// [percent] tam sayıdır (0–100). `100`, KAYITLI BÖLÜMÜN tamamlandığı
  /// anlamına gelir — sonraki bölüm sunucuya otomatik olarak `0` diye
  /// YAZILMAZ; sonraki bölüm gerekiyorsa yalnız
  /// `SeriesDetailResponse.episodes` yayın sırasından belirlenir.
  Future<ReadingProgressMutationResponse> upsertProgress({
    required String seriesSlug,
    required String episodeSlug,
    required int percent,
  });
}
