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

import 'account_capabilities.dart';
import 'account_provider_kind.dart';
import 'auth_user.dart';
import 'schema_version.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/AccountOverviewResponse`.
class AccountOverviewResponse {
  const AccountOverviewResponse({
    required this.schemaVersion,
    required this.user,
    required this.provider,
    required this.capabilities,
  });

  factory AccountOverviewResponse.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as String;
    if (schemaVersion != kSchemaVersion) {
      throw FormatException(
        'Desteklenmeyen schemaVersion: $schemaVersion '
        '(beklenen: $kSchemaVersion)',
      );
    }
    final user = AuthUser.fromJson(
      json['user'] as Map<String, dynamic>,
    );
    final provider = AccountProviderKind.fromJson(json['provider'] as String);
    final capabilities = AccountCapabilities.fromJson(
      json['capabilities'] as Map<String, dynamic>,
    );
    return AccountOverviewResponse(
      schemaVersion: schemaVersion,
      user: user,
      provider: provider,
      capabilities: capabilities,
    );
  }

  final String schemaVersion;
  final AuthUser user;
  final AccountProviderKind provider;
  final AccountCapabilities capabilities;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'user': user.toJson(),
      'provider': provider.toJson(),
      'capabilities': capabilities.toJson(),
    };
  }
}
