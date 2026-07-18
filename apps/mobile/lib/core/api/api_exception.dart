import 'package:flutter/foundation.dart';

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
/// yüzeye çıkar (bkz. `core/contracts/schema_version.dart`).
class SchemaMismatchException extends ApiException {
  const SchemaMismatchException(super.message);
}
