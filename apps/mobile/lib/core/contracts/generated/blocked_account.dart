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

/// Kaynak: `packages/contracts/schema.json` -> `$defs/BlockedAccount`.
class BlockedAccount {
  const BlockedAccount({
    required this.id,
    required this.displayName,
    this.avatarUrl,
  });

  factory BlockedAccount.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final displayName = json['displayName'] as String;
    final avatarUrl = json['avatarUrl'] as String?;
    return BlockedAccount(
      id: id,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
  }

  final String id;
  final String displayName;
  final String? avatarUrl;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
    };
  }
}
