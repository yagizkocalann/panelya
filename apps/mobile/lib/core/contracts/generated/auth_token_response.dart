// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

import 'auth_user.dart';
import 'schema_version.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/AuthTokenResponse`.
class AuthTokenResponse {
  const AuthTokenResponse({
    required this.schemaVersion,
    required this.tokenType,
    required this.accessToken,
    required this.expiresIn,
    required this.refreshToken,
    required this.scope,
    required this.user,
  });

  factory AuthTokenResponse.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as String;
    if (schemaVersion != kSchemaVersion) {
      throw FormatException(
        'Desteklenmeyen schemaVersion: $schemaVersion '
        '(beklenen: $kSchemaVersion)',
      );
    }
    final tokenType = json['tokenType'] as String;
    final accessToken = json['accessToken'] as String;
    final expiresIn = (json['expiresIn'] as num).toInt();
    final refreshToken = json['refreshToken'] as String;
    final scope = (json['scope'] as List<dynamic>).cast<String>();
    final user = AuthUser.fromJson(
      json['user'] as Map<String, dynamic>,
    );
    return AuthTokenResponse(
      schemaVersion: schemaVersion,
      tokenType: tokenType,
      accessToken: accessToken,
      expiresIn: expiresIn,
      refreshToken: refreshToken,
      scope: scope,
      user: user,
    );
  }

  final String schemaVersion;
  final String tokenType;
  final String accessToken;
  final int expiresIn;
  /// Rotating token. The client replaces the previous value atomically after every refresh.
  final String refreshToken;
  final List<String> scope;
  final AuthUser user;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'tokenType': tokenType,
      'accessToken': accessToken,
      'expiresIn': expiresIn,
      'refreshToken': refreshToken,
      'scope': scope,
      'user': user.toJson(),
    };
  }
}
