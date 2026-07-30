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

/// Kaynak: `packages/contracts/schema.json` -> `$defs/AccountReauthenticationStartResponse`.
class AccountReauthenticationStartResponse {
  const AccountReauthenticationStartResponse({
    required this.schemaVersion,
    required this.requestId,
    required this.authorizationUrl,
    required this.callbackUrlScheme,
    required this.expiresAt,
  });

  factory AccountReauthenticationStartResponse.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as String;
    if (schemaVersion != kSchemaVersion) {
      throw FormatException(
        'Desteklenmeyen schemaVersion: $schemaVersion '
        '(beklenen: $kSchemaVersion)',
      );
    }
    final requestId = json['requestId'] as String;
    final authorizationUrl = json['authorizationUrl'] as String;
    final callbackUrlScheme = json['callbackUrlScheme'] as String;
    final expiresAt = json['expiresAt'] as String;
    return AccountReauthenticationStartResponse(
      schemaVersion: schemaVersion,
      requestId: requestId,
      authorizationUrl: authorizationUrl,
      callbackUrlScheme: callbackUrlScheme,
      expiresAt: expiresAt,
    );
  }

  final String schemaVersion;
  final String requestId;
  final String authorizationUrl;
  final String callbackUrlScheme;
  final String expiresAt;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'requestId': requestId,
      'authorizationUrl': authorizationUrl,
      'callbackUrlScheme': callbackUrlScheme,
      'expiresAt': expiresAt,
    };
  }
}
