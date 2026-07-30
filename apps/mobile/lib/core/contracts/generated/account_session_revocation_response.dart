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

/// Kaynak: `packages/contracts/schema.json` -> `$defs/AccountSessionRevocationResponse`.
class AccountSessionRevocationResponse {
  const AccountSessionRevocationResponse({
    required this.schemaVersion,
    required this.revokedCount,
    required this.currentSessionRevoked,
  });

  factory AccountSessionRevocationResponse.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as String;
    if (schemaVersion != kSchemaVersion) {
      throw FormatException(
        'Desteklenmeyen schemaVersion: $schemaVersion '
        '(beklenen: $kSchemaVersion)',
      );
    }
    final revokedCount = (json['revokedCount'] as num).toInt();
    final currentSessionRevoked = json['currentSessionRevoked'] as bool;
    return AccountSessionRevocationResponse(
      schemaVersion: schemaVersion,
      revokedCount: revokedCount,
      currentSessionRevoked: currentSessionRevoked,
    );
  }

  final String schemaVersion;
  final int revokedCount;
  final bool currentSessionRevoked;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'revokedCount': revokedCount,
      'currentSessionRevoked': currentSessionRevoked,
    };
  }
}
