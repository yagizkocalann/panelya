import '../../../core/contracts/generated/generated.dart';

/// Editorial keşif verisine (`GET /api/discovery`) erişim sözleşmesi.
///
/// Panelya'da paylaşılan alan modelleri (seri, bölüm) için ayrı bir mobil
/// domain tipi türetilmez (bkz. docs/mobile-handoff.md Ortaklık kuralları
/// #2); bu repository doğrudan `packages/contracts/schema.json`'dan üretilen
/// `DiscoveryResponse` DTO'sunu (`lib/core/contracts/generated/`) döner.
/// Ekran widget'ları bu arayüzü yalnız Riverpod provider'ı
/// (`discoveryRepositoryProvider`) üzerinden kullanır; ham HTTP/JSON'a asla
/// dokunmaz.
abstract class DiscoveryRepository {
  /// `GET /api/discovery`.
  Future<DiscoveryResponse> fetchDiscovery();
}
