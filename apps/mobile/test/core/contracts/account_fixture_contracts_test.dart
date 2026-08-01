import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';

/// `packages/contracts/fixtures/account-*.v1.json` (SALT OKUNUR, ortak
/// sentetik fixture'lar, bkz. ADR-047 / docs/production-account-lifecycle.md)
/// ile `lib/core/contracts/generated/account_*.dart` DTO'larının ayrıştırma
/// uyumunu doğrular.
///
/// Fixture içerikleri buraya KOPYALANMAZ — her test dosyayı doğrudan
/// okur (bkz. `auth_fixture_contracts_test.dart` ile aynı desen). Böylece
/// web tarafı bir fixture'ı güncellediğinde bu testler gerçekten
/// kırılır/uyum sağlar; sabitlenmiş bir kopya sessizce eskimez.
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
  group('packages/contracts account fixture parity (generated DTOs)', () {
    test('18 hesap fixture dosyasının tamamı diskte mevcut', () {
      final files = Directory(_fixturesDir)
          .listSync()
          .whereType<File>()
          .map((file) => file.uri.pathSegments.last)
          .where((name) => name.startsWith('account-'))
          .toList();
      // Sözleşme teslimindeki fixture sayısı; yeni bir fixture eklenirse bu
      // test kasıtlı olarak kırılır ve buraya bir parser testi eklenmesi
      // gerektiğini hatırlatır.
      expect(files, hasLength(18));
    });

    test(
      'account-overview-database.v1.json parses with AccountOverviewResponse',
      () {
        final response = AccountOverviewResponse.fromJson(
          _readFixture('account-overview-database.v1.json'),
        );

        expect(response.schemaVersion, '1.0');
        expect(response.provider, AccountProviderKind.database);
        expect(response.user.id, 'user_fixture_01');
        expect(response.user.displayName, 'Deniz Kaya');
        expect(response.user.emailVerified, isTrue);
        expect(response.user.avatarUrl, isNull);
        expect(
          response.capabilities.profileEditing,
          AccountActionCapability.enabled,
        );
        expect(
          response.capabilities.avatarEditing,
          AccountActionCapability.unavailable,
        );
        expect(
          response.capabilities.emailChange,
          AccountActionCapability.reauthentication_required,
        );
        expect(
          response.capabilities.passwordAction,
          AccountActionCapability.enabled,
        );
        expect(
          response.capabilities.accountDeletion,
          AccountActionCapability.reauthentication_required,
        );

        final roundTripped = AccountOverviewResponse.fromJson(
          response.toJson(),
        );
        expect(roundTripped.provider, response.provider);
        expect(
          roundTripped.capabilities.emailChange,
          response.capabilities.emailChange,
        );
      },
    );

    test(
      'account-overview-google.v1.json: sosyal sağlayıcıda e-posta/şifre '
      'yetenekleri provider_managed olarak gelir',
      () {
        final response = AccountOverviewResponse.fromJson(
          _readFixture('account-overview-google.v1.json'),
        );

        expect(response.provider, AccountProviderKind.google);
        expect(response.user.avatarUrl, isNotNull);
        expect(
          response.capabilities.emailChange,
          AccountActionCapability.provider_managed,
        );
        expect(
          response.capabilities.passwordAction,
          AccountActionCapability.provider_managed,
        );
        expect(
          response.capabilities.avatarEditing,
          AccountActionCapability.provider_managed,
        );
        // Sosyal sağlayıcıda da yönetilebilen yetenekler:
        expect(
          response.capabilities.sessionManagement,
          AccountActionCapability.enabled,
        );
        expect(
          response.capabilities.blockedAccounts,
          AccountActionCapability.enabled,
        );
      },
    );

    test('account-profile-update-request.v1.json parses with '
        'AccountProfileUpdateRequest', () {
      final request = AccountProfileUpdateRequest.fromJson(
        _readFixture('account-profile-update-request.v1.json'),
      );

      expect(request.displayName, 'Deniz K.');
      expect(
        AccountProfileUpdateRequest.fromJson(request.toJson()).displayName,
        request.displayName,
      );
    });

    test(
      'account-password-reset-request.v1.json: alansız gövde ({}) '
      'AccountPasswordResetRequest ile ayrıştırılır ve toJson boş nesne döner',
      () {
        final json = _readFixture('account-password-reset-request.v1.json');
        expect(json, isEmpty);

        final request = AccountPasswordResetRequest.fromJson(json);
        expect(request.toJson(), isEmpty);
      },
    );

    test(
      'account-email-change-request.v1.json parses with '
      'AccountEmailChangeRequest (reauthenticationToken zorunlu)',
      () {
        final request = AccountEmailChangeRequest.fromJson(
          _readFixture('account-email-change-request.v1.json'),
        );

        expect(request.newEmail, 'deniz.yeni@example.test');
        expect(request.reauthenticationToken, isNotEmpty);
        expect(request.reauthenticationToken.length, greaterThanOrEqualTo(32));
      },
    );

    test(
      'account-action-accepted.v1.json parses with '
      'AccountActionAcceptedResponse',
      () {
        final response = AccountActionAcceptedResponse.fromJson(
          _readFixture('account-action-accepted.v1.json'),
        );

        expect(response.schemaVersion, '1.0');
        expect(response.accepted, isTrue);
      },
    );

    test(
      'account-reauthentication-start-request.v1.json parses with '
      'AccountReauthenticationStartRequest (S256 sabit)',
      () {
        final request = AccountReauthenticationStartRequest.fromJson(
          _readFixture('account-reauthentication-start-request.v1.json'),
        );

        expect(request.purpose, AccountReauthenticationPurpose.account_deletion);
        expect(request.redirectUri, 'panelya://auth/callback');
        expect(request.codeChallengeMethod, 'S256');
        expect(request.codeChallenge.length, greaterThanOrEqualTo(43));
      },
    );

    test(
      'account-reauthentication-start-response.v1.json parses with '
      'AccountReauthenticationStartResponse',
      () {
        final response = AccountReauthenticationStartResponse.fromJson(
          _readFixture('account-reauthentication-start-response.v1.json'),
        );

        expect(response.schemaVersion, '1.0');
        expect(response.requestId, 'reauth_request_fixture_01');
        expect(response.authorizationUrl, startsWith('https://'));
        expect(response.callbackUrlScheme, 'panelya');
        expect(response.expiresAt, isNotEmpty);
      },
    );

    test(
      'account-reauthentication-complete-request.v1.json parses with '
      'AccountReauthenticationCompleteRequest',
      () {
        final request = AccountReauthenticationCompleteRequest.fromJson(
          _readFixture('account-reauthentication-complete-request.v1.json'),
        );

        expect(request.requestId, 'reauth_request_fixture_01');
        expect(request.authorizationCode, isNotEmpty);
        expect(request.state, isNotEmpty);
        expect(request.codeVerifier.length, greaterThanOrEqualTo(43));
        expect(request.redirectUri, 'panelya://auth/callback');
      },
    );

    test(
      'account-reauthentication-complete-response.v1.json parses with '
      'AccountReauthenticationCompleteResponse (amaca bağlı token)',
      () {
        final response = AccountReauthenticationCompleteResponse.fromJson(
          _readFixture('account-reauthentication-complete-response.v1.json'),
        );

        expect(
          response.purpose,
          AccountReauthenticationPurpose.account_deletion,
        );
        expect(response.reauthenticationToken.length, greaterThanOrEqualTo(32));
        expect(response.expiresAt, isNotEmpty);
      },
    );

    test(
      'account-sessions.v1.json parses with AccountSessionsResponse '
      '(current/revocable alanları dahil)',
      () {
        final response = AccountSessionsResponse.fromJson(
          _readFixture('account-sessions.v1.json'),
        );

        expect(response.sessions, hasLength(2));

        final current = response.sessions.firstWhere((s) => s.current);
        expect(current.id, 'session_fixture_android_01');
        expect(current.platform, AccountSessionPlatform.android);
        expect(current.revocable, isTrue);
        // Sözleşmede `lastActiveAt` bir STRING'dir (ISO-8601), DateTime
        // değil — istemci gerektiğinde kendisi parse eder.
        expect(current.lastActiveAt, '2030-01-01T12:00:00.000Z');

        final other = response.sessions.firstWhere((s) => !s.current);
        expect(other.platform, AccountSessionPlatform.web);
      },
    );

    test(
      'account-session-revocation-request.v1.json parses with '
      'AccountSessionRevocationRequest',
      () {
        final request = AccountSessionRevocationRequest.fromJson(
          _readFixture('account-session-revocation-request.v1.json'),
        );

        expect(request.scope, 'others');
      },
    );

    test(
      'account-session-revocation-response.v1.json parses with '
      'AccountSessionRevocationResponse (currentSessionRevoked dahil)',
      () {
        final response = AccountSessionRevocationResponse.fromJson(
          _readFixture('account-session-revocation-response.v1.json'),
        );

        expect(response.revokedCount, 1);
        expect(response.currentSessionRevoked, isFalse);
      },
    );

    test('account-blocks.v1.json parses with BlockedAccountsResponse', () {
      final response = BlockedAccountsResponse.fromJson(
        _readFixture('account-blocks.v1.json'),
      );

      expect(response.accounts, hasLength(1));
      expect(response.accounts.single.id, 'user_fixture_blocked_01');
      expect(response.accounts.single.displayName, 'Ornek Okur');
      expect(response.accounts.single.avatarUrl, isNotNull);
    });

    test(
      'account-deletion-summary.v1.json parses with '
      'AccountDeletionSummaryResponse (deleted/anonymized/retained)',
      () {
        final response = AccountDeletionSummaryResponse.fromJson(
          _readFixture('account-deletion-summary.v1.json'),
        );

        expect(
          response.deleted,
          containsAll([
            AccountDeletionEffect.auth_identity,
            AccountDeletionEffect.profile,
            AccountDeletionEffect.active_sessions,
          ]),
        );
        expect(response.anonymized, [
          AccountDeletionEffect.community_contributions,
        ]);
        // `retained` bilerek ayrı bir listedir: silinmeyen/anonimleşmeyen,
        // yasal olarak saklanan kayıtlar kullanıcıya dürüstçe gösterilir.
        expect(response.retained, [
          AccountDeletionEffect.legal_and_audit_records,
        ]);
      },
    );

    test(
      'account-deletion-request.v1.json parses with AccountDeletionRequest '
      '(sabit confirmation + reauthenticationToken)',
      () {
        final request = AccountDeletionRequest.fromJson(
          _readFixture('account-deletion-request.v1.json'),
        );

        expect(request.confirmation, 'delete_my_account');
        expect(request.reauthenticationToken.length, greaterThanOrEqualTo(32));
      },
    );

    test(
      'account-deletion-response.v1.json parses with '
      'AccountDeletionOperationResponse (status pending olabilir)',
      () {
        final response = AccountDeletionOperationResponse.fromJson(
          _readFixture('account-deletion-response.v1.json'),
        );

        expect(response.requestId, 'deletion_request_fixture_01');
        // Silme ASENKRON olabilir — istemci `pending`i de doğru ele almalı.
        expect(response.status, 'pending');
      },
    );

    test(
      'account-error.v1.json parses with AccountErrorResponse '
      '(reauthenticate bayrağı dahil)',
      () {
        final response = AccountErrorResponse.fromJson(
          _readFixture('account-error.v1.json'),
        );

        expect(response.error, 'reauthentication_expired');
        expect(response.errorDescription, isNotNull);
        expect(response.reauthenticate, isTrue);
        expect(response.retryAfterSeconds, isNull);
      },
    );
  });
}
