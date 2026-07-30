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

/// Kaynak: `packages/contracts/schema.json` -> `$defs/AccountProfileUpdateRequest`.
class AccountProfileUpdateRequest {
  const AccountProfileUpdateRequest({
    required this.displayName,
  });

  factory AccountProfileUpdateRequest.fromJson(Map<String, dynamic> json) {
    final displayName = json['displayName'] as String;
    return AccountProfileUpdateRequest(
      displayName: displayName,
    );
  }

  final String displayName;

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
    };
  }
}
