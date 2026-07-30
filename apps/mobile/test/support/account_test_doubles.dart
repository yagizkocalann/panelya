import 'dart:async';

import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/account/domain/account_repository.dart';

/// Hiçbir çağrısı TAMAMLANMAYAN [AccountRepository] — ekranları kalıcı
/// olarak "yükleniyor" durumunda dondurmak için (bkz.
/// `test/app/router/router_test.dart`'ın aynı gerekçesi: `Completer` bir
/// `Timer` yaratmaz, bu yüzden `pumpAndSettle` asılı kalmaz).
///
/// Sözleşmenin 12 metodunu tek yerde karşılar; her test dosyasında
/// kopyalanmaz.
class NeverResolvingAccountRepository implements AccountRepository {
  @override
  Future<AccountOverviewResponse> fetchOverview() =>
      Completer<AccountOverviewResponse>().future;

  @override
  Future<AccountOverviewResponse> updateProfile({
    required String displayName,
  }) => Completer<AccountOverviewResponse>().future;

  @override
  Future<AccountActionAcceptedResponse> requestPasswordReset() =>
      Completer<AccountActionAcceptedResponse>().future;

  @override
  Future<AccountActionAcceptedResponse> requestEmailChange({
    required String newEmail,
    required String reauthenticationToken,
  }) => Completer<AccountActionAcceptedResponse>().future;

  @override
  Future<AccountSessionsResponse> fetchSessions() =>
      Completer<AccountSessionsResponse>().future;

  @override
  Future<AccountSessionRevocationResponse> revokeSession(String sessionId) =>
      Completer<AccountSessionRevocationResponse>().future;

  @override
  Future<AccountSessionRevocationResponse> revokeSessions({
    required String scope,
  }) => Completer<AccountSessionRevocationResponse>().future;

  @override
  Future<BlockedAccountsResponse> fetchBlockedAccounts() =>
      Completer<BlockedAccountsResponse>().future;

  @override
  Future<AccountActionAcceptedResponse> unblockAccount(String userId) =>
      Completer<AccountActionAcceptedResponse>().future;

  @override
  Future<AccountDeletionSummaryResponse> fetchDeletionSummary() =>
      Completer<AccountDeletionSummaryResponse>().future;

  @override
  Future<AccountDeletionOperationResponse> deleteAccount({
    required String reauthenticationToken,
  }) => Completer<AccountDeletionOperationResponse>().future;

  @override
  Future<AccountReauthenticationStartResponse> startReauthentication({
    required AccountReauthenticationPurpose purpose,
    required String redirectUri,
    required String codeChallenge,
  }) => Completer<AccountReauthenticationStartResponse>().future;

  @override
  Future<AccountReauthenticationCompleteResponse> completeReauthentication({
    required String requestId,
    required String authorizationCode,
    required String state,
    required String codeVerifier,
    required String redirectUri,
  }) => Completer<AccountReauthenticationCompleteResponse>().future;
}

/// Sözleşmenin `AccountCapabilities`'ini testlerde kısa yoldan kurmak için.
/// Varsayılan: her yetenek `enabled` (avatar hariç — gerçek sözleşmede de
/// mobilde desteklenmiyor).
AccountCapabilities testCapabilities({
  AccountActionCapability profileEditing = AccountActionCapability.enabled,
  AccountActionCapability avatarEditing = AccountActionCapability.unavailable,
  AccountActionCapability emailChange = AccountActionCapability.enabled,
  AccountActionCapability passwordAction = AccountActionCapability.enabled,
  AccountActionCapability sessionManagement = AccountActionCapability.enabled,
  AccountActionCapability blockedAccounts = AccountActionCapability.enabled,
  AccountActionCapability accountDeletion = AccountActionCapability.enabled,
}) => AccountCapabilities(
  profileEditing: profileEditing,
  avatarEditing: avatarEditing,
  emailChange: emailChange,
  passwordAction: passwordAction,
  sessionManagement: sessionManagement,
  blockedAccounts: blockedAccounts,
  accountDeletion: accountDeletion,
);

/// Testlerde kullanılan sabit oturum kaydı üreticisi.
AccountSession testSession({
  required String id,
  required String deviceLabel,
  AccountSessionPlatform platform = AccountSessionPlatform.android,
  String lastActiveAt = '2030-01-01T12:00:00.000Z',
  bool current = false,
  bool revocable = true,
}) => AccountSession(
  id: id,
  deviceLabel: deviceLabel,
  platform: platform,
  lastActiveAt: lastActiveAt,
  current: current,
  revocable: revocable,
);
