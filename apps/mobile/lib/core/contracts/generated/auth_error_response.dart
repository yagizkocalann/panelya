// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

import 'schema_version.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/AuthErrorResponse`.
class AuthErrorResponse {
  const AuthErrorResponse({
    required this.schemaVersion,
    required this.error,
    this.errorDescription,
    required this.reauthenticate,
    this.retryAfterSeconds,
  });

  factory AuthErrorResponse.fromJson(Map<String, dynamic> json) {
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
    return AuthErrorResponse(
      schemaVersion: schemaVersion,
      error: error,
      errorDescription: errorDescription,
      reauthenticate: reauthenticate,
      retryAfterSeconds: retryAfterSeconds,
    );
  }

  final String schemaVersion;
  /// Bilinen değer kümesi: "user_cancelled" | "invalid_grant" | "login_required" | "token_expired" | "token_reused" | "insufficient_scope" | "session_revoked" | "rate_limited" | "service_unavailable".
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
