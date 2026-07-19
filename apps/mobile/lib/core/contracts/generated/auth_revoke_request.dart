// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

/// Kaynak: `packages/contracts/schema.json` -> `$defs/AuthRevokeRequest`.
class AuthRevokeRequest {
  const AuthRevokeRequest({
    required this.refreshToken,
  });

  factory AuthRevokeRequest.fromJson(Map<String, dynamic> json) {
    final refreshToken = json['refreshToken'] as String;
    return AuthRevokeRequest(
      refreshToken: refreshToken,
    );
  }

  final String refreshToken;

  Map<String, dynamic> toJson() {
    return {
      'refreshToken': refreshToken,
    };
  }
}
