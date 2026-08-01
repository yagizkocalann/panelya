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

import 'library_status.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/LibraryUpsertRequest`.
class LibraryUpsertRequest {
  const LibraryUpsertRequest({
    required this.status,
    required this.favorite,
  });

  factory LibraryUpsertRequest.fromJson(Map<String, dynamic> json) {
    final status = LibraryStatus.fromJson(json['status'] as String);
    final favorite = json['favorite'] as bool;
    return LibraryUpsertRequest(
      status: status,
      favorite: favorite,
    );
  }

  final LibraryStatus status;
  final bool favorite;

  Map<String, dynamic> toJson() {
    return {
      'status': status.toJson(),
      'favorite': favorite,
    };
  }
}
