import 'package:flutter/foundation.dart';

import '../contracts/generated/generated.dart';

/// Merkezi API client'ın fırlattığı tüm hataların ortak tipi.
///
/// Ekranlar hata durumunu göstermek için yalnız [ApiException] ve alt
/// tiplerini yakalar; ham `http`/`dio` istisnalarını doğrudan görmez
/// (bkz. PLAN madde 5 — network/4xx/5xx/parse ayrımı).
@immutable
sealed class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Bağlantı kurulamadı, zaman aşımına uğradı veya soket hatası oluştu.
/// Kullanıcıya "tekrar dene" seçeneği sunulmalıdır.
class NetworkException extends ApiException {
  const NetworkException(super.message, {this.cause});

  final Object? cause;
}

/// Sunucu bir HTTP hata durum kodu döndürdü. `statusCode` 400-499 ise
/// istemci hatası (örn. 404 seri/bölüm yok), 500-599 ise sunucu hatasıdır;
/// [isClientError] / [isServerError] bu ayrımı yapar.
class HttpStatusException extends ApiException {
  const HttpStatusException({
    required this.statusCode,
    required this.path,
    this.errorCode,
  }) : super('HTTP $statusCode: $path');

  final int statusCode;
  final String path;

  /// Sunucunun `{"error": "..."}` gövdesinden okunan hata kodu (varsa),
  /// örn. `series_not_found`, `episode_not_found`.
  final String? errorCode;

  bool get isClientError => statusCode >= 400 && statusCode < 500;
  bool get isServerError => statusCode >= 500 && statusCode < 600;
  bool get isNotFound => statusCode == 404;
}

/// Sunucu 200 döndü ama gövde beklenen JSON şeklinde değildi (bozuk JSON
/// veya beklenmeyen alan tipleri).
class ParseException extends ApiException {
  const ParseException(super.message, {this.cause});

  final Object? cause;
}

/// Sunucunun `schemaVersion` alanı bu istemcinin desteklediği sürümle
/// eşleşmiyor. Sessizce yanlış alan okumak yerine açık bir hata olarak
/// yüzeye çıkar (bkz. `core/api/api_client.dart` — `kSchemaVersion`
/// karşılaştırması, ve üretilen `lib/core/contracts/generated/
/// schema_version.dart`).
class SchemaMismatchException extends ApiException {
  const SchemaMismatchException(super.message);
}

/// `/api/auth/*` uçlarından dönen, `{"error": "...", "reauthenticate": ...}`
/// şeklindeki (bkz. `AuthErrorResponse`) yapılandırılmış hata.
///
/// Kasıtlı olarak [ApiException]'ı GENİŞLETMEZ (o `sealed`; bu tip onun bir
/// alt tipi olsaydı, `describeApiException` gibi mevcut, auth'tan bağımsız
/// `switch` ifadeleri de bu yeni dalı ele almak zorunda kalırdı — bkz.
/// `api_error_presenter.dart`, yalnız discover/series/reader ekranları
/// için). Genel [HttpStatusException]'dan da ayrı tutulur çünkü çağıran
/// (bkz. `features/auth/data/http_auth_repository.dart`) `error` koduna
/// göre (`token_reused`, `session_revoked`, `rate_limited`, ...) farklı
/// davranmak zorundadır (bkz. ADR-039 "Oturum ve hata kuralları");
/// statusCode tek başına bu ayrımı taşımaz.
@immutable
class AuthApiException implements Exception {
  const AuthApiException(this.error);

  final AuthErrorResponse error;

  @override
  String toString() =>
      'AuthApiException: ${error.errorDescription ?? error.error}';
}
