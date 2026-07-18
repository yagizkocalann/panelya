import '../../../core/contracts/series_detail_response.dart';

/// Seri detay verisine erişim sözleşmesi.
///
/// (bkz. docs/mobile-handoff.md Ortaklık kuralları #2 — bağımsız mobil
/// domain tipi türetilmez, `core/contracts` doğrudan kullanılır.)
abstract class SeriesRepository {
  /// `GET /api/series/:slug`. Seri bulunamazsa
  /// `HttpStatusException(statusCode: 404)` fırlatır.
  Future<SeriesDetailResponse> fetchSeriesDetail(String slug);
}
