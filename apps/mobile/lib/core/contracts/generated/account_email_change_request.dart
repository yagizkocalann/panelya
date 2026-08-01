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

/// Kaynak: `packages/contracts/schema.json` -> `$defs/AccountEmailChangeRequest`.
class AccountEmailChangeRequest {
  const AccountEmailChangeRequest({
    required this.newEmail,
    required this.reauthenticationToken,
  });

  factory AccountEmailChangeRequest.fromJson(Map<String, dynamic> json) {
    final newEmail = json['newEmail'] as String;
    final reauthenticationToken = json['reauthenticationToken'] as String;
    return AccountEmailChangeRequest(
      newEmail: newEmail,
      reauthenticationToken: reauthenticationToken,
    );
  }

  final String newEmail;
  final String reauthenticationToken;

  Map<String, dynamic> toJson() {
    return {
      'newEmail': newEmail,
      'reauthenticationToken': reauthenticationToken,
    };
  }
}
