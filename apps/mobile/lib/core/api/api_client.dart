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

  // --- Auth (bkz. ADR-039, docs/production-auth-session.md) ----------------
  //
  // Bu dört metot yalnız `HttpAuthRepository` (bkz.
  // `lib/features/auth/data/http_auth_repository.dart`) tarafından çağrılır;
  // o repository de gerçek Auth0 tenant/gateway/JWKS değerleri sağlanana
  // kadar `authRepositoryProvider` içinde BAĞLANMAZ (bkz. o dosyadaki
  // sınır notu). Web tarafı bu uçları bugün "fail closed" döndürür (bkz.
  // `app/lib/production-auth.ts` -> `productionAuthUnavailable()`, HTTP 503,
  // `error: "service_unavailable"`); bu metotlar o cevabı da doğru şekilde
  // [AuthApiException] olarak yüzeye çıkarır.

  /// `GET /api/auth/config` — Auth0 sağlayıcı yapılandırması (issuer, public
  /// client id, audience, scope, endpoint'ler). Secret dönmez.
  Future<AuthProviderConfigResponse> fetchAuthConfig() {
    return _authGetJson('/api/auth/config', AuthProviderConfigResponse.fromJson);
  }

  /// `POST /api/auth/mobile/token` (`grantType: authorization_code`) — ilk
  /// mobil oturum: authorization code + PKCE verifier değişimi.
  Future<AuthTokenResponse> exchangeAuthorizationCode(
    AuthAuthorizationCodeExchangeRequest request,
  ) {
    return _authPostJson(
      '/api/auth/mobile/token',
      request.toJson(),
      AuthTokenResponse.fromJson,
    );
  }

  /// `POST /api/auth/mobile/token` (`grantType: refresh_token`) — dönen
  /// refresh token ile yenileme; yanıt hem yeni access hem yeni refresh
  /// tokeni taşır (bkz. ADR-039 rotasyon kuralı).
  Future<AuthTokenResponse> refreshAuthToken(AuthRefreshTokenRequest request) {
    return _authPostJson(
      '/api/auth/mobile/token',
      request.toJson(),
      AuthTokenResponse.fromJson,
    );
  }

  /// `POST /api/auth/mobile/revoke` — refresh grantini iptal eder. Aynı
  /// isteğin tekrarı da başarılı kabul edilir (bkz. ADR-039).
  Future<AuthLogoutResponse> revokeAuthToken(AuthRevokeRequest request) {
    return _authPostJson(
      '/api/auth/mobile/revoke',
      request.toJson(),
      AuthLogoutResponse.fromJson,
    );
  }

  Future<T> _authGetJson<T>(
    String path,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    http.Response response;
    try {
      response = await _httpClient
          .get(Uri.parse('$apiOrigin$path'))
          .timeout(timeout);
    } on TimeoutException catch (cause) {
      throw NetworkException('İstek zaman aşımına uğradı: $path', cause: cause);
    } on SocketException catch (cause) {
      throw NetworkException('Sunucuya bağlanılamadı: $path', cause: cause);
    } on http.ClientException catch (cause) {
      throw NetworkException('Ağ hatası: $path', cause: cause);
    }
    return _decodeAuthResponse(path, response, fromJson);
  }

  Future<T> _authPostJson<T>(
    String path,
    Map<String, dynamic> body,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    http.Response response;
    try {
      response = await _httpClient
          .post(
            Uri.parse('$apiOrigin$path'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException catch (cause) {
      throw NetworkException('İstek zaman aşımına uğradı: $path', cause: cause);
    } on SocketException catch (cause) {
      throw NetworkException('Sunucuya bağlanılamadı: $path', cause: cause);
    } on http.ClientException catch (cause) {
      throw NetworkException('Ağ hatası: $path', cause: cause);
    }
    return _decodeAuthResponse(path, response, fromJson);
  }

  T _decodeAuthResponse<T>(
    String path,
    http.Response response,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (cause) {
      throw ParseException('Geçersiz JSON gövdesi: $path', cause: cause);
    }

    if (decoded is! Map<String, dynamic>) {
      throw ParseException('Beklenmeyen JSON şekli: $path');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Auth uçları hata gövdesini her zaman `AuthErrorResponse` şeklinde
      // döner (bkz. `packages/contracts/fixtures/auth-error.v1.json`); bu
      // yüzden burada genel [HttpStatusException] değil, çağıranın `error`
      // koduna göre davranabileceği [AuthApiException] fırlatılır.
      try {
        throw AuthApiException(AuthErrorResponse.fromJson(decoded));
      } on TypeError {
        throw HttpStatusException(statusCode: response.statusCode, path: path);
      } on FormatException {
        throw HttpStatusException(statusCode: response.statusCode, path: path);
      }
    }

    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion != null && schemaVersion != kSchemaVersion) {
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
