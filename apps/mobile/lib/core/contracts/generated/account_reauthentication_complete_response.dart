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

import 'account_reauthentication_purpose.dart';
import 'schema_version.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/AccountReauthenticationCompleteResponse`.
class AccountReauthenticationCompleteResponse {
  const AccountReauthenticationCompleteResponse({
    required this.schemaVersion,
    required this.purpose,
    required this.reauthenticationToken,
    required this.expiresAt,
  });

  factory AccountReauthenticationCompleteResponse.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as String;
    if (schemaVersion != kSchemaVersion) {
      throw FormatException(
        'Desteklenmeyen schemaVersion: $schemaVersion '
        '(beklenen: $kSchemaVersion)',
      );
    }
    final purpose = AccountReauthenticationPurpose.fromJson(json['purpose'] as String);
    final reauthenticationToken = json['reauthenticationToken'] as String;
    final expiresAt = json['expiresAt'] as String;
    return AccountReauthenticationCompleteResponse(
      schemaVersion: schemaVersion,
      purpose: purpose,
      reauthenticationToken: reauthenticationToken,
      expiresAt: expiresAt,
    );
  }

  final String schemaVersion;
  final AccountReauthenticationPurpose purpose;
  final String reauthenticationToken;
  final String expiresAt;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'purpose': purpose.toJson(),
      'reauthenticationToken': reauthenticationToken,
      'expiresAt': expiresAt,
    };
  }
}
