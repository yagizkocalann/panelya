// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

import 'auth_user.dart';
import 'schema_version.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/AuthStateResponse`.
class AuthStateResponse {
  const AuthStateResponse({
    required this.schemaVersion,
    required this.authenticated,
    required this.user,
  });

  factory AuthStateResponse.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as String;
    if (schemaVersion != kSchemaVersion) {
      throw FormatException(
        'Desteklenmeyen schemaVersion: $schemaVersion '
        '(beklenen: $kSchemaVersion)',
      );
    }
    final authenticated = json['authenticated'] as bool;
    final userRaw = json['user'];
    final user = userRaw == null
        ? null
        : AuthUser.fromJson(
            userRaw as Map<String, dynamic>,
          );
    return AuthStateResponse(
      schemaVersion: schemaVersion,
      authenticated: authenticated,
      user: user,
    );
  }

  final String schemaVersion;
  final bool authenticated;
  final AuthUser? user;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'authenticated': authenticated,
      'user': user?.toJson(),
    };
  }
}
