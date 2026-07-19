import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../contracts/generated/generated.dart';
import 'api_exception.dart';

/// Panelya web deployment'ının API sınırına konuşan tek merkezi HTTP
/// istemcisi.
///
/// Ekran widget'ları bu sınıfı doğrudan çağırmaz; yalnız
/// `lib/core/api/*_repository.dart` implementasyonları üzerinden, onlar da
/// yalnız Riverpod repository provider'ları üzerinden kullanılır (bkz.
/// docs/mobile-handoff.md Ortaklık kuralları #5). Mobil istemci D1/R2'ye
/// doğrudan bağlanmaz; yalnız bu sınıfın konuştuğu `/api/*` uçlarını kullanır.
///
/// Gövdeler `lib/core/contracts/generated/` altındaki, `packages/contracts/
/// schema.json`'dan üretilen DTO'larla ayrıştırılır (bkz.
/// docs/mobile-handoff.md Ortaklık kuralları #3 — geçici elle yazılmış
/// adapter, ortak sözleşme kaynağı `main`'e gelip codegen kurulduktan sonra
/// kaldırıldı).
class PanelyaApiClient {
  PanelyaApiClient({
    required this.apiOrigin,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
  }) : _httpClient = httpClient ?? http.Client();

  /// Web deployment'ının API sınırı, örn. `http://localhost:3000`.
  final String apiOrigin;
  final http.Client _httpClient;
  final Duration timeout;

  /// `GET /api/catalog` — keşif/katalog kartları ve öne çıkan seri.
  Future<CatalogResponse> fetchCatalog() {
    return _getJson('/api/catalog', CatalogResponse.fromJson);
  }

  /// `GET /api/series/:slug` — seri, türler ve bölüm listesi.
  Future<SeriesDetailResponse> fetchSeriesDetail(String slug) {
    return _getJson(
      '/api/series/${Uri.encodeComponent(slug)}',
      SeriesDetailResponse.fromJson,
    );
  }

  /// `GET /api/series/:slug/episodes/:episodeSlug` — okuyucu manifesti.
  Future<EpisodeManifestResponse> fetchEpisodeManifest(
    String seriesSlug,
    String episodeSlug,
  ) {
    return _getJson(
      '/api/series/${Uri.encodeComponent(seriesSlug)}/episodes/${Uri.encodeComponent(episodeSlug)}',
      EpisodeManifestResponse.fromJson,
    );
  }

  Future<T> _getJson<T>(
    String path,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    final uri = Uri.parse('$apiOrigin$path');
    http.Response response;
    try {
      response = await _httpClient.get(uri).timeout(timeout);
    } on TimeoutException catch (cause) {
      throw NetworkException('İstek zaman aşımına uğradı: $path', cause: cause);
    } on SocketException catch (cause) {
      throw NetworkException('Sunucuya bağlanılamadı: $path', cause: cause);
    } on http.ClientException catch (cause) {
      throw NetworkException('Ağ hatası: $path', cause: cause);
    }

    if (response.statusCode != 200) {
      String? errorCode;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          errorCode = ErrorResponse.fromJson(decoded).error;
        }
      } catch (_) {
        // Hata gövdesi JSON değilse veya `ErrorResponse` şeklinde
        // (`{"error": "..."}`) değilse errorCode null kalır; statusCode
        // yeterli.
      }
      throw HttpStatusException(
        statusCode: response.statusCode,
        path: path,
        errorCode: errorCode,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (cause) {
      throw ParseException('Geçersiz JSON gövdesi: $path', cause: cause);
    }

    if (decoded is! Map<String, dynamic>) {
      throw ParseException('Beklenmeyen JSON şekli: $path');
    }

    // `schemaVersion` uyumsuzluğu, üretilen DTO'nun kendi `fromJson`'ı
    // çağrılmadan ÖNCE burada kontrol edilir: üretilen `fromJson` uyumsuz
    // bir sürüm için düz bir `FormatException` fırlatır (bkz.
    // `lib/core/contracts/generated/*_response.dart`), bu da aşağıdaki genel
    // parse-hatası kolundan ayırt edilemez. Erken, açık bir kontrolle
    // [SchemaMismatchException] her zaman doğru şekilde yüzeye çıkar (bkz.
    // PLAN madde 5 — schemaVersion uyumsuzluğunda açık hata).
    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion != kSchemaVersion) {
      throw SchemaMismatchException(
        '$path şu sürümü döndürdü: $schemaVersion, beklenen: $kSchemaVersion',
      );
    }

    try {
      return fromJson(decoded);
    } on TypeError catch (cause) {
      throw ParseException('JSON şekli sözleşmeyle eşleşmiyor: $path', cause: cause);
    } on FormatException catch (cause) {
      throw ParseException('JSON şekli sözleşmeyle eşleşmiyor: $path', cause: cause);
    }
  }

  void close() => _httpClient.close();
}

/// Aktif [PanelyaApiClient]. `apiConfigProvider`'daki origin'i kullanır;
/// origin hiçbir zaman kaynak koda gömülmez.
final apiClientProvider = Provider<PanelyaApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = PanelyaApiClient(apiOrigin: config.apiOrigin);
  ref.onDispose(client.close);
  return client;
});
