// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

import 'schema_version.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/AuthLogoutResponse`.
class AuthLogoutResponse {
  const AuthLogoutResponse({
    required this.schemaVersion,
    required this.revoked,
  });

  factory AuthLogoutResponse.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as String;
    if (schemaVersion != kSchemaVersion) {
      throw FormatException(
        'Desteklenmeyen schemaVersion: $schemaVersion '
        '(beklenen: $kSchemaVersion)',
      );
    }
    final revoked = json['revoked'] as bool;
    return AuthLogoutResponse(
      schemaVersion: schemaVersion,
      revoked: revoked,
    );
  }

  final String schemaVersion;
  final bool revoked;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'revoked': revoked,
    };
  }
}
