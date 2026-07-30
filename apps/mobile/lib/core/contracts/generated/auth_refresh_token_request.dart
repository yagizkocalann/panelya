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

/// Kaynak: `packages/contracts/schema.json` -> `$defs/AuthRefreshTokenRequest`.
class AuthRefreshTokenRequest {
  const AuthRefreshTokenRequest({
    required this.grantType,
    required this.refreshToken,
  });

  factory AuthRefreshTokenRequest.fromJson(Map<String, dynamic> json) {
    final grantType = json['grantType'] as String;
    final refreshToken = json['refreshToken'] as String;
    return AuthRefreshTokenRequest(
      grantType: grantType,
      refreshToken: refreshToken,
    );
  }

  final String grantType;
  final String refreshToken;

  Map<String, dynamic> toJson() {
    return {
      'grantType': grantType,
      'refreshToken': refreshToken,
    };
  }
}
