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

/// Kaynak: `packages/contracts/schema.json` -> `$defs/AccountActionAcceptedResponse`.
class AccountActionAcceptedResponse {
  const AccountActionAcceptedResponse({
    required this.schemaVersion,
    required this.accepted,
  });

  factory AccountActionAcceptedResponse.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as String;
    if (schemaVersion != kSchemaVersion) {
      throw FormatException(
        'Desteklenmeyen schemaVersion: $schemaVersion '
        '(beklenen: $kSchemaVersion)',
      );
    }
    final accepted = json['accepted'] as bool;
    return AccountActionAcceptedResponse(
      schemaVersion: schemaVersion,
      accepted: accepted,
    );
  }

  final String schemaVersion;
  final bool accepted;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'accepted': accepted,
    };
  }
}
