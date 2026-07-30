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

/// Kaynak: `packages/contracts/schema.json` -> `$defs/AccountDeletionOperationResponse`.
class AccountDeletionOperationResponse {
  const AccountDeletionOperationResponse({
    required this.schemaVersion,
    required this.requestId,
    required this.status,
  });

  factory AccountDeletionOperationResponse.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as String;
    if (schemaVersion != kSchemaVersion) {
      throw FormatException(
        'Desteklenmeyen schemaVersion: $schemaVersion '
        '(beklenen: $kSchemaVersion)',
      );
    }
    final requestId = json['requestId'] as String;
    final status = json['status'] as String;
    return AccountDeletionOperationResponse(
      schemaVersion: schemaVersion,
      requestId: requestId,
      status: status,
    );
  }

  final String schemaVersion;
  final String requestId;
  /// Bilinen değer kümesi: "pending" | "completed".
  final String status;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'requestId': requestId,
      'status': status,
    };
  }
}
