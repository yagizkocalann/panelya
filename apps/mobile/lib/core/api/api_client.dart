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

  /// `GET /api/discovery` — editorial keşif akışı: öne çıkan seri/ilk
  /// bölümü, ortak tür listesi, sunucunun 30 günlük kuralıyla belirlediği
  /// yeni seriler ve gerçek yayın sırasındaki en fazla 100 bölüm güncellemesi
  /// (bkz. docs/mobile-handoff.md "Editorial keşif akışı" ve ADR-044). İstemci
  /// bu listelerin sırasını asla yeniden hesaplamaz/sıralamaz.
  Future<DiscoveryResponse> fetchDiscovery() {
    return _getJson('/api/discovery', DiscoveryResponse.fromJson);
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
  // Bu metotlar yalnız `HttpAuthRepository` (bkz.
  // `lib/features/auth/data/http_auth_repository.dart`) tarafından çağrılır.
  // Web tarafı bu uçları yalnız tenant/gateway değerleri eksikken "fail
  // closed" döndürür (bkz. `app/lib/production-auth.ts` ->
  // `productionAuthUnavailable()`, HTTP 503, `error: "service_unavailable"`);
  // bu metotlar o cevabı da doğru şekilde [AuthApiException] olarak yüzeye
  // çıkarır.

  /// `GET /api/auth/config` — Auth0 sağlayıcı yapılandırması (issuer, public
  /// client id, audience, scope, endpoint'ler). Secret dönmez.
  Future<AuthProviderConfigResponse> fetchAuthConfig() {
    return _authGetJson(
      '/api/auth/config',
      AuthProviderConfigResponse.fromJson,
    );
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

  /// `GET /api/auth/me` — bir access tokenin gerçekten Panelya kullanıcısına
  /// eşlendiğini doğrular (bkz. ADR-039 "Kullanıcı özeti"). `HttpAuthRepository`
  /// bunu hem `completeSignIn` sonrası ikinci bir doğrulama katmanı olarak hem
  /// de uygulama yeniden açılışında saklı oturumu geri yüklerken kullanır.
  /// [accessToken] verilmezse `Authorization` başlığı hiç gönderilmez (bu
  /// yalnız web çerez tabanlı yol için anlamlıdır, mobil her zaman token
  /// geçer).
  Future<AuthStateResponse> fetchAuthState({String? accessToken}) {
    return _authGetJson(
      '/api/auth/me',
      AuthStateResponse.fromJson,
      headers: accessToken == null
          ? null
          : {'Authorization': 'Bearer $accessToken'},
    );
  }

  // --- Hesap yasam dongusu (bkz. ADR-047, docs/production-account-lifecycle.md)
  //
  // Mobil, web ile AYNI `/api/account/*` JSON sözleşmesini kullanır (ayrı bir
  // `/api/account/mobile/*` AÇILMADI); tek fark kimlik taşıma biçimidir —
  // web host-only cookie, mobil `Authorization: Bearer`. Bu metotlar yalnız
  // `HttpAccountRepository` (bkz. `features/account/data/`) tarafından
  // çağrılır ve hata gövdesini [AccountApiException] olarak yüzeye çıkarır.

  /// `GET /api/account`
  Future<AccountOverviewResponse> fetchAccountOverview({
    required String accessToken,
  }) {
    return _accountJson(
      'GET',
      '/api/account',
      accessToken,
      AccountOverviewResponse.fromJson,
    );
  }

  /// `PATCH /api/account/profile` — tazelenmiş özeti döner.
  Future<AccountOverviewResponse> updateAccountProfile({
    required String accessToken,
    required AccountProfileUpdateRequest request,
  }) {
    return _accountJson(
      'PATCH',
      '/api/account/profile',
      accessToken,
      AccountOverviewResponse.fromJson,
      body: request.toJson(),
    );
  }

  /// `POST /api/account/password-reset` — gövdesi alansızdır.
  Future<AccountActionAcceptedResponse> requestAccountPasswordReset({
    required String accessToken,
  }) {
    return _accountJson(
      'POST',
      '/api/account/password-reset',
      accessToken,
      AccountActionAcceptedResponse.fromJson,
      body: const AccountPasswordResetRequest().toJson(),
    );
  }

  /// `POST /api/account/email-change`
  Future<AccountActionAcceptedResponse> requestAccountEmailChange({
    required String accessToken,
    required AccountEmailChangeRequest request,
  }) {
    return _accountJson(
      'POST',
      '/api/account/email-change',
      accessToken,
      AccountActionAcceptedResponse.fromJson,
      body: request.toJson(),
    );
  }

  /// `GET /api/account/sessions`
  Future<AccountSessionsResponse> fetchAccountSessions({
    required String accessToken,
  }) {
    return _accountJson(
      'GET',
      '/api/account/sessions',
      accessToken,
      AccountSessionsResponse.fromJson,
    );
  }

  /// `DELETE /api/account/sessions/{sessionId}`
  Future<AccountSessionRevocationResponse> revokeAccountSession({
    required String accessToken,
    required String sessionId,
  }) {
    return _accountJson(
      'DELETE',
      '/api/account/sessions/${Uri.encodeComponent(sessionId)}',
      accessToken,
      AccountSessionRevocationResponse.fromJson,
    );
  }

  /// `POST /api/account/sessions/revoke`
  Future<AccountSessionRevocationResponse> revokeAccountSessions({
    required String accessToken,
    required AccountSessionRevocationRequest request,
  }) {
    return _accountJson(
      'POST',
      '/api/account/sessions/revoke',
      accessToken,
      AccountSessionRevocationResponse.fromJson,
      body: request.toJson(),
    );
  }

  /// `GET /api/account/blocks`
  Future<BlockedAccountsResponse> fetchAccountBlocks({
    required String accessToken,
  }) {
    return _accountJson(
      'GET',
      '/api/account/blocks',
      accessToken,
      BlockedAccountsResponse.fromJson,
    );
  }

  /// `DELETE /api/account/blocks/{userId}`
  Future<AccountActionAcceptedResponse> unblockAccount({
    required String accessToken,
    required String userId,
  }) {
    return _accountJson(
      'DELETE',
      '/api/account/blocks/${Uri.encodeComponent(userId)}',
      accessToken,
      AccountActionAcceptedResponse.fromJson,
    );
  }

  /// `GET /api/account/deletion`
  Future<AccountDeletionSummaryResponse> fetchAccountDeletionSummary({
    required String accessToken,
  }) {
    return _accountJson(
      'GET',
      '/api/account/deletion',
      accessToken,
      AccountDeletionSummaryResponse.fromJson,
    );
  }

  /// `POST /api/account/deletion` — sözleşme gereği ZORUNLU
  /// `Idempotency-Key` header'ı gönderilir; aynı anahtarla tekrar çağrı
  /// sunucuda yeni bir iş OLUŞTURMAZ.
  Future<AccountDeletionOperationResponse> deleteAccount({
    required String accessToken,
    required AccountDeletionRequest request,
    required String idempotencyKey,
  }) {
    return _accountJson(
      'POST',
      '/api/account/deletion',
      accessToken,
      AccountDeletionOperationResponse.fromJson,
      body: request.toJson(),
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
  }

  /// `POST /api/account/reauthentication/start`
  Future<AccountReauthenticationStartResponse> startAccountReauthentication({
    required String accessToken,
    required AccountReauthenticationStartRequest request,
  }) {
    return _accountJson(
      'POST',
      '/api/account/reauthentication/start',
      accessToken,
      AccountReauthenticationStartResponse.fromJson,
      body: request.toJson(),
    );
  }

  /// `POST /api/account/reauthentication/complete`
  Future<AccountReauthenticationCompleteResponse>
  completeAccountReauthentication({
    required String accessToken,
    required AccountReauthenticationCompleteRequest request,
  }) {
    return _accountJson(
      'POST',
      '/api/account/reauthentication/complete',
      accessToken,
      AccountReauthenticationCompleteResponse.fromJson,
      body: request.toJson(),
    );
  }

  /// `GET /api/progress` — kullanicinin okuma ilerlemesi.
  ///
  /// Sunucunun SIRASI korunur; istemci yeniden siralama URETMEZ.
  Future<ReadingProgressResponse> fetchReadingProgress({
    required String accessToken,
  }) {
    return _progressJson(
      'GET',
      '/api/progress',
      accessToken,
      ReadingProgressResponse.fromJson,
    );
  }

  /// `POST /api/progress` — ilerleme yazimi.
  ///
  /// TOGGLE veya DELTA DEGILDIR: hedef durumun tamami (`seriesSlug`,
  /// `episodeSlug`, tam sayi `percent`) gonderilir.
  Future<ReadingProgressMutationResponse> upsertReadingProgress({
    required String accessToken,
    required ReadingProgressUpsertRequest request,
  }) {
    return _progressJson(
      'POST',
      '/api/progress',
      accessToken,
      ReadingProgressMutationResponse.fromJson,
      body: request.toJson(),
    );
  }

  /// [_libraryJson]in ilerleme esdegeri; hata govdesi
  /// [ReadingProgressErrorResponse] olarak ayristirilir.
  Future<T> _progressJson<T>(
    String method,
    String path,
    String accessToken,
    T Function(Map<String, dynamic> json) fromJson, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$apiOrigin$path');
    final headers = <String, String>{
      'Authorization': 'Bearer $accessToken',
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };

    http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _httpClient.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException catch (cause) {
      throw NetworkException('Istek zaman asimina ugradi: $path', cause: cause);
    } on SocketException catch (cause) {
      throw NetworkException('Sunucuya baglanilamadi: $path', cause: cause);
    } on http.ClientException catch (cause) {
      throw NetworkException('Ag hatasi: $path', cause: cause);
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (cause) {
      throw ParseException('Gecersiz JSON govdesi: $path', cause: cause);
    }
    if (decoded is! Map<String, dynamic>) {
      throw ParseException('Beklenmeyen JSON sekli: $path');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      try {
        throw ReadingProgressApiException(
          ReadingProgressErrorResponse.fromJson(decoded),
        );
      } on TypeError {
        throw HttpStatusException(statusCode: response.statusCode, path: path);
      } on FormatException {
        throw HttpStatusException(statusCode: response.statusCode, path: path);
      }
    }

    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion != null && schemaVersion != kSchemaVersion) {
      throw SchemaMismatchException(
        '$path su surumu dondurdu: $schemaVersion, beklenen: $kSchemaVersion',
      );
    }

    try {
      return fromJson(decoded);
    } on TypeError catch (cause) {
      throw ParseException(
        'JSON sekli sozlesmeyle eslesmiyor: $path',
        cause: cause,
      );
    } on FormatException catch (cause) {
      throw ParseException(
        'JSON sekli sozlesmeyle eslesmiyor: $path',
        cause: cause,
      );
    }
  }

  /// `GET /api/library` — kullanicinin kutuphanesi.
  ///
  /// Sunucunun verdigi SIRALAMA korunur; istemci `updatedAt` veya Turkce
  /// gosterim metninden yeniden siralama URETMEZ (bkz. ADR-048).
  Future<LibraryResponse> fetchLibrary({required String accessToken}) {
    return _libraryJson(
      'GET',
      '/api/library',
      accessToken,
      LibraryResponse.fromJson,
    );
  }

  /// `POST /api/library/{slug}` — seri ekleme/guncelleme.
  ///
  /// Govde TOGGLE DEGILDIR: hedef durumun tamami (`status` + `favorite`)
  /// gonderilir (bkz. `LibraryUpsertRequest`).
  Future<LibraryMutationResponse> upsertLibraryEntry({
    required String accessToken,
    required String slug,
    required LibraryUpsertRequest request,
  }) {
    return _libraryJson(
      'POST',
      '/api/library/${Uri.encodeComponent(slug)}',
      accessToken,
      LibraryMutationResponse.fromJson,
      body: request.toJson(),
    );
  }

  /// `DELETE /api/library/{slug}` — kutuphaneden cikarma.
  ///
  /// IDEMPOTENT: kayit zaten yoksa sunucu `removed: false` ile 200 doner;
  /// bu bir HATA DEGILDIR.
  Future<LibraryRemovalResponse> removeLibraryEntry({
    required String accessToken,
    required String slug,
  }) {
    return _libraryJson(
      'DELETE',
      '/api/library/${Uri.encodeComponent(slug)}',
      accessToken,
      LibraryRemovalResponse.fromJson,
    );
  }

  /// [_accountJson]in kutuphane esdegeri. Tek fark hata govdesinin
  /// [LibraryErrorResponse] olarak ayristirilmasi ve [LibraryApiException]
  /// firlatilmasidir — iki sozlesmenin hata sekilleri farklidir.
  ///
  /// Kimlik YALNIZ `Authorization: Bearer` ile tasinir; web'in cookie
  /// oturumu mobilde KULLANILMAZ (OpenAPI 1.5.0 ikisini de tanimlar,
  /// mobil istemci Bearer semasini secer).
  Future<T> _libraryJson<T>(
    String method,
    String path,
    String accessToken,
    T Function(Map<String, dynamic> json) fromJson, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$apiOrigin$path');
    final headers = <String, String>{
      'Authorization': 'Bearer $accessToken',
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };

    http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _httpClient.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException catch (cause) {
      throw NetworkException('Istek zaman asimina ugradi: $path', cause: cause);
    } on SocketException catch (cause) {
      throw NetworkException('Sunucuya baglanilamadi: $path', cause: cause);
    } on http.ClientException catch (cause) {
      throw NetworkException('Ag hatasi: $path', cause: cause);
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (cause) {
      throw ParseException('Gecersiz JSON govdesi: $path', cause: cause);
    }
    if (decoded is! Map<String, dynamic>) {
      throw ParseException('Beklenmeyen JSON sekli: $path');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      try {
        throw LibraryApiException(LibraryErrorResponse.fromJson(decoded));
      } on TypeError {
        throw HttpStatusException(statusCode: response.statusCode, path: path);
      } on FormatException {
        throw HttpStatusException(statusCode: response.statusCode, path: path);
      }
    }

    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion != null && schemaVersion != kSchemaVersion) {
      throw SchemaMismatchException(
        '$path su surumu dondurdu: $schemaVersion, beklenen: $kSchemaVersion',
      );
    }

    try {
      return fromJson(decoded);
    } on TypeError catch (cause) {
      throw ParseException(
        'JSON sekli sozlesmeyle eslesmiyor: $path',
        cause: cause,
      );
    } on FormatException catch (cause) {
      throw ParseException(
        'JSON sekli sozlesmeyle eslesmiyor: $path',
        cause: cause,
      );
    }
  }

  Future<T> _accountJson<T>(
    String method,
    String path,
    String accessToken,
    T Function(Map<String, dynamic> json) fromJson, {
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
  }) async {
    final uri = Uri.parse('$apiOrigin$path');
    final headers = <String, String>{
      'Authorization': 'Bearer $accessToken',
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      ...?extraHeaders,
    };

    http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _httpClient.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException catch (cause) {
      throw NetworkException('İstek zaman aşımına uğradı: $path', cause: cause);
    } on SocketException catch (cause) {
      throw NetworkException('Sunucuya bağlanılamadı: $path', cause: cause);
    } on http.ClientException catch (cause) {
      throw NetworkException('Ağ hatası: $path', cause: cause);
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

    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Hesap uçları hata gövdesini her zaman `AccountErrorResponse`
      // şeklinde döner (bkz. `packages/contracts/fixtures/account-error.v1.json`).
      try {
        throw AccountApiException(AccountErrorResponse.fromJson(decoded));
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
      throw ParseException(
        'JSON şekli sözleşmeyle eşleşmiyor: $path',
        cause: cause,
      );
    } on FormatException catch (cause) {
      throw ParseException(
        'JSON şekli sözleşmeyle eşleşmiyor: $path',
        cause: cause,
      );
    }
  }

  Future<T> _authGetJson<T>(
    String path,
    T Function(Map<String, dynamic> json) fromJson, {
    Map<String, String>? headers,
  }) async {
    http.Response response;
    try {
      response = await _httpClient
          .get(Uri.parse('$apiOrigin$path'), headers: headers)
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
      throw ParseException(
        'JSON şekli sözleşmeyle eşleşmiyor: $path',
        cause: cause,
      );
    } on FormatException catch (cause) {
      throw ParseException(
        'JSON şekli sözleşmeyle eşleşmiyor: $path',
        cause: cause,
      );
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
      throw ParseException(
        'JSON şekli sözleşmeyle eşleşmiyor: $path',
        cause: cause,
      );
    } on FormatException catch (cause) {
      throw ParseException(
        'JSON şekli sözleşmeyle eşleşmiyor: $path',
        cause: cause,
      );
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
