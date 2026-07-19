import '../../../core/contracts/generated/generated.dart';

/// Seri detay verisine erişim sözleşmesi.
///
/// (bkz. docs/mobile-handoff.md Ortaklık kuralları #2 — bağımsız mobil
/// domain tipi türetilmez, `packages/contracts/schema.json`'dan üretilen
/// DTO'lar (`lib/core/contracts/generated/`) doğrudan kullanılır.)
abstract class SeriesRepository {
  /// `GET /api/series/:slug`. Seri bulunamazsa
  /// `HttpStatusException(statusCode: 404)` fırlatır.
  Future<SeriesDetailResponse> fetchSeriesDetail(String slug);
}
