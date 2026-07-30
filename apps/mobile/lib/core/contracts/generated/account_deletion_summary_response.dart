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

import 'account_deletion_effect.dart';
import 'schema_version.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/AccountDeletionSummaryResponse`.
class AccountDeletionSummaryResponse {
  const AccountDeletionSummaryResponse({
    required this.schemaVersion,
    required this.deleted,
    required this.anonymized,
    required this.retained,
  });

  factory AccountDeletionSummaryResponse.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as String;
    if (schemaVersion != kSchemaVersion) {
      throw FormatException(
        'Desteklenmeyen schemaVersion: $schemaVersion '
        '(beklenen: $kSchemaVersion)',
      );
    }
    final deleted = (json['deleted'] as List<dynamic>)
        .map((item) => AccountDeletionEffect.fromJson(item as String))
        .toList(growable: false);
    final anonymized = (json['anonymized'] as List<dynamic>)
        .map((item) => AccountDeletionEffect.fromJson(item as String))
        .toList(growable: false);
    final retained = (json['retained'] as List<dynamic>)
        .map((item) => AccountDeletionEffect.fromJson(item as String))
        .toList(growable: false);
    return AccountDeletionSummaryResponse(
      schemaVersion: schemaVersion,
      deleted: deleted,
      anonymized: anonymized,
      retained: retained,
    );
  }

  final String schemaVersion;
  final List<AccountDeletionEffect> deleted;
  final List<AccountDeletionEffect> anonymized;
  final List<AccountDeletionEffect> retained;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'deleted': deleted.map((e) => e.toJson()).toList(),
      'anonymized': anonymized.map((e) => e.toJson()).toList(),
      'retained': retained.map((e) => e.toJson()).toList(),
    };
  }
}
