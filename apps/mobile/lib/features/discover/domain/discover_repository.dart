import '../../../core/contracts/catalog_response.dart';

/// Keşif/katalog verisine erişim sözleşmesi.
///
/// Panelya'da paylaşılan alan modelleri (seri, bölüm, panel) için ayrı bir
/// mobil domain tipi türetilmez (bkz. docs/mobile-handoff.md Ortaklık
/// kuralları #2); bu repository doğrudan `core/contracts` altındaki geçici
/// adapter tiplerini döner. Ekran widget'ları bu arayüzü yalnız Riverpod
/// provider'ı (`discoverRepositoryProvider`) üzerinden kullanır.
abstract class DiscoverRepository {
  /// `GET /api/catalog`.
  Future<CatalogResponse> fetchCatalog();
}
