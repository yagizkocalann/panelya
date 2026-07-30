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

import 'blocked_account.dart';
import 'schema_version.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/BlockedAccountsResponse`.
class BlockedAccountsResponse {
  const BlockedAccountsResponse({
    required this.schemaVersion,
    required this.accounts,
  });

  factory BlockedAccountsResponse.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as String;
    if (schemaVersion != kSchemaVersion) {
      throw FormatException(
        'Desteklenmeyen schemaVersion: $schemaVersion '
        '(beklenen: $kSchemaVersion)',
      );
    }
    final accounts = (json['accounts'] as List<dynamic>)
        .map(
          (item) => BlockedAccount.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
    return BlockedAccountsResponse(
      schemaVersion: schemaVersion,
      accounts: accounts,
    );
  }

  final String schemaVersion;
  final List<BlockedAccount> accounts;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'accounts': accounts.map((e) => e.toJson()).toList(),
    };
  }
}
