// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

/// Kaynak: `packages/contracts/schema.json` -> `$defs/AuthAuthorizationCodeExchangeRequest`.
class AuthAuthorizationCodeExchangeRequest {
  const AuthAuthorizationCodeExchangeRequest({
    required this.grantType,
    required this.authorizationCode,
    required this.codeVerifier,
    required this.redirectUri,
  });

  factory AuthAuthorizationCodeExchangeRequest.fromJson(Map<String, dynamic> json) {
    final grantType = json['grantType'] as String;
    final authorizationCode = json['authorizationCode'] as String;
    final codeVerifier = json['codeVerifier'] as String;
    final redirectUri = json['redirectUri'] as String;
    return AuthAuthorizationCodeExchangeRequest(
      grantType: grantType,
      authorizationCode: authorizationCode,
      codeVerifier: codeVerifier,
      redirectUri: redirectUri,
    );
  }

  final String grantType;
  final String authorizationCode;
  final String codeVerifier;
  final String redirectUri;

  Map<String, dynamic> toJson() {
    return {
      'grantType': grantType,
      'authorizationCode': authorizationCode,
      'codeVerifier': codeVerifier,
      'redirectUri': redirectUri,
    };
  }
}
