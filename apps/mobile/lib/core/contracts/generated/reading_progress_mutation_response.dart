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

import 'reading_progress_item.dart';
import 'schema_version.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/ReadingProgressMutationResponse`.
class ReadingProgressMutationResponse {
  const ReadingProgressMutationResponse({
    required this.schemaVersion,
    required this.item,
  });

  factory ReadingProgressMutationResponse.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as String;
    if (schemaVersion != kSchemaVersion) {
      throw FormatException(
        'Desteklenmeyen schemaVersion: $schemaVersion '
        '(beklenen: $kSchemaVersion)',
      );
    }
    final item = ReadingProgressItem.fromJson(
      json['item'] as Map<String, dynamic>,
    );
    return ReadingProgressMutationResponse(
      schemaVersion: schemaVersion,
      item: item,
    );
  }

  final String schemaVersion;
  final ReadingProgressItem item;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'item': item.toJson(),
    };
  }
}
