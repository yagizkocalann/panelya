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

/// Kaynak: `packages/contracts/schema.json` -> `$defs/AccountErrorResponse`.
class AccountErrorResponse {
  const AccountErrorResponse({
    required this.schemaVersion,
    required this.error,
    this.errorDescription,
    required this.reauthenticate,
    this.retryAfterSeconds,
  });

  factory AccountErrorResponse.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as String;
    if (schemaVersion != kSchemaVersion) {
      throw FormatException(
        'Desteklenmeyen schemaVersion: $schemaVersion '
        '(beklenen: $kSchemaVersion)',
      );
    }
    final error = json['error'] as String;
    final errorDescription = json['errorDescription'] as String?;
    final reauthenticate = json['reauthenticate'] as bool;
    final retryAfterSeconds = (json['retryAfterSeconds'] as num?)?.toInt();
    return AccountErrorResponse(
      schemaVersion: schemaVersion,
      error: error,
      errorDescription: errorDescription,
      reauthenticate: reauthenticate,
      retryAfterSeconds: retryAfterSeconds,
    );
  }

  final String schemaVersion;
  /// Bilinen değer kümesi: "not_authenticated" | "invalid_request" | "unsupported_action" | "reauthentication_required" | "reauthentication_invalid" | "reauthentication_expired" | "reauthentication_reused" | "not_found" | "conflict" | "rate_limited" | "service_unavailable".
  final String error;
  final String? errorDescription;
  final bool reauthenticate;
  final int? retryAfterSeconds;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'error': error,
      'errorDescription': errorDescription,
      'reauthenticate': reauthenticate,
      'retryAfterSeconds': retryAfterSeconds,
    };
  }
}
