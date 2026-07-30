import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';

/// `packages/contracts/fixtures/auth-*.v1.json` (SALT OKUNUR, ortak
/// sentetik fixture'lar, bkz. ADR-039) ile `lib/core/contracts/generated/
/// auth_*.dart` DTO'larının ayrıştırma uyumunu doğrular (bkz.
/// `test/core/contracts/fixture_contracts_test.dart` ile aynı desen —
/// fixture içerikleri buraya kopyalanmaz, yalnız dosyadan okunur).
///
/// `flutter test` her zaman paket kökünden (`apps/mobile`) çalıştırıldığı
/// için repo köküne göre relative yol `../../packages/contracts/fixtures`
/// olur.
const _fixturesDir = '../../packages/contracts/fixtures';

Map<String, dynamic> _readFixture(String name) {
  final file = File('$_fixturesDir/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('packages/contracts auth fixture parity (generated DTOs)', () {
    test('auth-config.v1.json parses with AuthProviderConfigResponse', () {
      final json = _readFixture('auth-config.v1.json');
      final config = AuthProviderConfigResponse.fromJson(json);

      expect(config.schemaVersion, '1.0');
      expect(config.provider, 'auth0');
      expect(config.flow, 'authorization_code_pkce');
      expect(config.issuer, 'https://auth.panelya.example/');
      expect(config.clientId, 'panelya-mobile-public-client');
      expect(config.audience, 'https://api.panelya.example');
      expect(config.scopes, contains('offline_access'));
      expect(
        config.authorizationEndpoint,
        'https://auth.panelya.example/authorize',
      );
      expect(config.tokenEndpoint, 'https://auth.panelya.example/oauth/token');
      expect(
        config.revocationEndpoint,
        'https://auth.panelya.example/oauth/revoke',
      );
      expect(config.accessTokenLifetimeSeconds, 900);
      expect(config.refreshTokenRotation, isTrue);

      final roundTripped = AuthProviderConfigResponse.fromJson(
        config.toJson(),
      );
      expect(roundTripped.clientId, config.clientId);
    });

    test('auth-token.v1.json parses with AuthTokenResponse', () {
      final json = _readFixture('auth-token.v1.json');
      final response = AuthTokenResponse.fromJson(json);

      expect(response.schemaVersion, '1.0');
      expect(response.tokenType, 'Bearer');
      expect(response.accessToken, isNotEmpty);
      expect(response.expiresIn, 900);
      expect(response.refreshToken, isNotEmpty);
      expect(response.scope, contains('write:progress'));
      expect(response.user.id, 'user_fixture_01');
      expect(response.user.displayName, 'Deniz Kaya');
      expect(response.user.email, 'deniz@example.test');
      expect(response.user.emailVerified, isTrue);
      expect(response.user.role, 'reader');
      expect(response.user.avatarUrl, isNull);

      final roundTripped = AuthTokenResponse.fromJson(response.toJson());
      expect(roundTripped.user.id, response.user.id);
    });

    test(
      'auth-state-anonymous.v1.json parses with AuthStateResponse '
      '(authenticated: false, user: null)',
      () {
        final json = _readFixture('auth-state-anonymous.v1.json');
        final response = AuthStateResponse.fromJson(json);

        expect(response.schemaVersion, '1.0');
        expect(response.authenticated, isFalse);
        expect(response.user, isNull);
      },
    );

    test(
      'auth-state-authenticated.v1.json parses with AuthStateResponse',
      () {
        final json = _readFixture('auth-state-authenticated.v1.json');
        final response = AuthStateResponse.fromJson(json);

        expect(response.schemaVersion, '1.0');
        expect(response.authenticated, isTrue);
        expect(response.user?.id, 'user_fixture_01');
        expect(response.user?.role, 'reader');
      },
    );

    test(
      'auth-code-exchange-request.v1.json parses with '
      'AuthAuthorizationCodeExchangeRequest',
      () {
        final json = _readFixture('auth-code-exchange-request.v1.json');
        final request = AuthAuthorizationCodeExchangeRequest.fromJson(json);

        expect(request.grantType, 'authorization_code');
        expect(request.authorizationCode, isNotEmpty);
        expect(request.codeVerifier, isNotEmpty);
        expect(request.redirectUri, contains('://auth/callback'));
      },
    );

    test(
      'auth-refresh-request.v1.json parses with AuthRefreshTokenRequest',
      () {
        final json = _readFixture('auth-refresh-request.v1.json');
        final request = AuthRefreshTokenRequest.fromJson(json);

        expect(request.grantType, 'refresh_token');
        expect(request.refreshToken, isNotEmpty);
      },
    );

    test('auth-revoke-request.v1.json parses with AuthRevokeRequest', () {
      final json = _readFixture('auth-revoke-request.v1.json');
      final request = AuthRevokeRequest.fromJson(json);

      expect(request.refreshToken, isNotEmpty);
    });

    test('auth-logout.v1.json parses with AuthLogoutResponse', () {
      final json = _readFixture('auth-logout.v1.json');
      final response = AuthLogoutResponse.fromJson(json);

      expect(response.schemaVersion, '1.0');
      expect(response.revoked, isTrue);
    });

    test('auth-error.v1.json parses with AuthErrorResponse', () {
      final json = _readFixture('auth-error.v1.json');
      final response = AuthErrorResponse.fromJson(json);

      expect(response.schemaVersion, '1.0');
      expect(response.error, 'token_reused');
      expect(response.errorDescription, isNotEmpty);
      expect(response.reauthenticate, isTrue);
      expect(response.retryAfterSeconds, isNull);
    });

    test(
      'fixture tokens/domains are synthetic (.example/.test/never-valid), '
      'never something the client should treat as reachable',
      () {
        final config = AuthProviderConfigResponse.fromJson(
          _readFixture('auth-config.v1.json'),
        );
        final token = AuthTokenResponse.fromJson(
          _readFixture('auth-token.v1.json'),
        );

        expect(config.issuer, contains('.example'));
        expect(token.user.email, contains('.test'));
        expect(token.accessToken, contains('never_valid'));
        expect(token.refreshToken, contains('never_valid'));
      },
    );
  });
}
