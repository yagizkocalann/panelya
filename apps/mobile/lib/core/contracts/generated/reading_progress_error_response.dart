// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).
//
// `constant_identifier_names` KAPALI: üretilen enum üyeleri şemadaki
// JSON değerlerini (ör. `provider_managed`, `auth_identity`) BİREBİR
// yansıtır. lowerCamelCase'e çevirmek, `fromJson`/`toJson`
// eşlemesini şemadan görsel olarak ayırır ve sessiz bir eşleme
// hatası riski yaratır; sözleşmeyle bire bir aynı kalması bilinçli
// bir tercihtir.
// ignore_for_file: constant_identifier_names

import 'schema_version.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/ReadingProgressErrorResponse`.
class ReadingProgressErrorResponse {
  const ReadingProgressErrorResponse({
    required this.schemaVersion,
    required this.error,
    this.errorDescription,
    this.retryAfterSeconds,
  });

  factory ReadingProgressErrorResponse.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as String;
    if (schemaVersion != kSchemaVersion) {
      throw FormatException(
        'Desteklenmeyen schemaVersion: $schemaVersion '
        '(beklenen: $kSchemaVersion)',
      );
    }
    final error = json['error'] as String;
    final errorDescription = json['errorDescription'] as String?;
    final retryAfterSeconds = (json['retryAfterSeconds'] as num?)?.toInt();
    return ReadingProgressErrorResponse(
      schemaVersion: schemaVersion,
      error: error,
      errorDescription: errorDescription,
      retryAfterSeconds: retryAfterSeconds,
    );
  }

  final String schemaVersion;
  /// Bilinen değer kümesi: "not_authenticated" | "insufficient_scope" | "invalid_request" | "not_found" | "rate_limited" | "service_unavailable".
  final String error;
  final String? errorDescription;
  final int? retryAfterSeconds;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'error': error,
      'errorDescription': errorDescription,
      'retryAfterSeconds': retryAfterSeconds,
    };
  }
}
