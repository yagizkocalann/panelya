// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

import 'schema_version.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/AuthProviderConfigResponse`.
class AuthProviderConfigResponse {
  const AuthProviderConfigResponse({
    required this.schemaVersion,
    required this.provider,
    required this.flow,
    required this.issuer,
    required this.clientId,
    required this.audience,
    required this.scopes,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.revocationEndpoint,
    required this.accessTokenLifetimeSeconds,
    required this.refreshTokenRotation,
  });

  factory AuthProviderConfigResponse.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as String;
    if (schemaVersion != kSchemaVersion) {
      throw FormatException(
        'Desteklenmeyen schemaVersion: $schemaVersion '
        '(beklenen: $kSchemaVersion)',
      );
    }
    final provider = json['provider'] as String;
    final flow = json['flow'] as String;
    final issuer = json['issuer'] as String;
    final clientId = json['clientId'] as String;
    final audience = json['audience'] as String;
    final scopes = (json['scopes'] as List<dynamic>).cast<String>();
    final authorizationEndpoint = json['authorizationEndpoint'] as String;
    final tokenEndpoint = json['tokenEndpoint'] as String;
    final revocationEndpoint = json['revocationEndpoint'] as String;
    final accessTokenLifetimeSeconds = (json['accessTokenLifetimeSeconds'] as num).toInt();
    final refreshTokenRotation = json['refreshTokenRotation'] as bool;
    return AuthProviderConfigResponse(
      schemaVersion: schemaVersion,
      provider: provider,
      flow: flow,
      issuer: issuer,
      clientId: clientId,
      audience: audience,
      scopes: scopes,
      authorizationEndpoint: authorizationEndpoint,
      tokenEndpoint: tokenEndpoint,
      revocationEndpoint: revocationEndpoint,
      accessTokenLifetimeSeconds: accessTokenLifetimeSeconds,
      refreshTokenRotation: refreshTokenRotation,
    );
  }

  final String schemaVersion;
  final String provider;
  final String flow;
  final String issuer;
  /// Public native-application client identifier; never a client secret.
  final String clientId;
  final String audience;
  final List<String> scopes;
  final String authorizationEndpoint;
  final String tokenEndpoint;
  final String revocationEndpoint;
  final int accessTokenLifetimeSeconds;
  final bool refreshTokenRotation;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'provider': provider,
      'flow': flow,
      'issuer': issuer,
      'clientId': clientId,
      'audience': audience,
      'scopes': scopes,
      'authorizationEndpoint': authorizationEndpoint,
      'tokenEndpoint': tokenEndpoint,
      'revocationEndpoint': revocationEndpoint,
      'accessTokenLifetimeSeconds': accessTokenLifetimeSeconds,
      'refreshTokenRotation': refreshTokenRotation,
    };
  }
}
