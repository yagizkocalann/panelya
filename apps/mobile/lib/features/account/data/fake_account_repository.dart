import '../../../core/contracts/generated/generated.dart';
import '../domain/account_repository.dart';

/// [AccountRepository]'nin in-memory sahte implementasyonu — ARTIK YALNIZ
/// TESTLERDE ve açıkça seçilmiş bir geliştirme önizlemesinde kullanılır.
///
/// Gerçek runtime `accountRepositoryProvider` üzerinden
/// [HttpAccountRepository]'yi bağlar (bkz. `presentation/account_providers.dart`);
/// bu sınıf onun yerine geçmez. Sözleşmeden ÜRETİLEN DTO'ları döndürür —
/// elle yazılmış provisional model kalmadı.
class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({
    this.provider = AccountProviderKind.database,
    AccountCapabilities? capabilities,
    List<AccountSession>? sessions,
    List<BlockedAccount>? blockedAccounts,
    AccountDeletionSummaryResponse? deletionSummary,
    AuthUser? user,
  }) : capabilities = capabilities ?? _defaultCapabilities,
       _sessions = List.of(sessions ?? _defaultSessions),
       _blockedAccounts = List.of(blockedAccounts ?? const []),
       _deletionSummary = deletionSummary ?? _defaultDeletionSummary,
       user = user ?? _defaultUser;

  final AccountProviderKind provider;
  final AccountCapabilities capabilities;
  final AuthUser user;
  final List<AccountSession> _sessions;
  final List<BlockedAccount> _blockedAccounts;
  final AccountDeletionSummaryResponse _deletionSummary;

  /// Çağrı sırasını/sayısını doğrulamak için.
  final List<String> calls = [];

  Object? fetchOverviewError;
  Object? updateProfileError;
  Object? requestPasswordResetError;
  Object? requestEmailChangeError;
  Object? fetchSessionsError;
  Object? revokeSessionError;
  Object? revokeSessionsError;
  Object? fetchBlockedAccountsError;
  Object? unblockAccountError;
  Object? fetchDeletionSummaryError;
  Object? deleteAccountError;
  Object? startReauthenticationError;
  Object? completeReauthenticationError;

  String? lastUpdatedDisplayName;
  String? lastRequestedEmail;
  String? lastEmailChangeToken;
  String? lastDeletionToken;
  String? lastRevokeScope;
  String? lastCodeChallenge;
  String? lastCodeVerifier;

  /// [revokeSession] çağrısında dönecek `currentSessionRevoked` değeri;
  /// testler mevcut-cihaz senaryosunu bununla sürer.
  bool revokeSessionRevokesCurrent = false;

  static const _defaultUser = AuthUser(
    id: 'fake-user',
    displayName: 'Sahte Kullanıcı',
    email: 'fake@panelya.invalid',
    emailVerified: true,
    role: 'reader',
  );

  static const _defaultCapabilities = AccountCapabilities(
    profileEditing: AccountActionCapability.enabled,
    avatarEditing: AccountActionCapability.unavailable,
    emailChange: AccountActionCapability.reauthentication_required,
    passwordAction: AccountActionCapability.enabled,
    sessionManagement: AccountActionCapability.enabled,
    blockedAccounts: AccountActionCapability.enabled,
    accountDeletion: AccountActionCapability.reauthentication_required,
  );

  static const List<AccountSession> _defaultSessions = [
    AccountSession(
      id: 'fake-session-current',
      deviceLabel: 'Bu cihaz — Android',
      platform: AccountSessionPlatform.android,
      lastActiveAt: '2030-01-01T12:00:00.000Z',
      current: true,
      revocable: true,
    ),
    AccountSession(
      id: 'fake-session-web',
      deviceLabel: 'Chrome — Windows',
      platform: AccountSessionPlatform.web,
      lastActiveAt: '2030-01-01T10:00:00.000Z',
      current: false,
      revocable: true,
    ),
  ];

  static const _defaultDeletionSummary = AccountDeletionSummaryResponse(
    schemaVersion: kSchemaVersion,
    deleted: [
      AccountDeletionEffect.auth_identity,
      AccountDeletionEffect.profile,
      AccountDeletionEffect.active_sessions,
    ],
    anonymized: [AccountDeletionEffect.community_contributions],
    retained: [AccountDeletionEffect.legal_and_audit_records],
  );

  Future<void> _maybeThrow(Object? error) async {
    if (error != null) Error.throwWithStackTrace(error, StackTrace.current);
  }

  AccountOverviewResponse _overview() => AccountOverviewResponse(
    schemaVersion: kSchemaVersion,
    user: user,
    provider: provider,
    capabilities: capabilities,
  );

  static const _accepted = AccountActionAcceptedResponse(
    schemaVersion: kSchemaVersion,
    accepted: true,
  );

  @override
  Future<AccountOverviewResponse> fetchOverview() async {
    calls.add('fetchOverview');
    await _maybeThrow(fetchOverviewError);
    return _overview();
  }

  @override
  Future<AccountOverviewResponse> updateProfile({
    required String displayName,
  }) async {
    calls.add('updateProfile');
    await _maybeThrow(updateProfileError);
    lastUpdatedDisplayName = displayName;
    return AccountOverviewResponse(
      schemaVersion: kSchemaVersion,
      user: AuthUser(
        id: user.id,
        displayName: displayName,
        email: user.email,
        emailVerified: user.emailVerified,
        role: user.role,
        avatarUrl: user.avatarUrl,
      ),
      provider: provider,
      capabilities: capabilities,
    );
  }

  @override
  Future<AccountActionAcceptedResponse> requestPasswordReset() async {
    calls.add('requestPasswordReset');
    await _maybeThrow(requestPasswordResetError);
    return _accepted;
  }

  @override
  Future<AccountActionAcceptedResponse> requestEmailChange({
    required String newEmail,
    required String reauthenticationToken,
  }) async {
    calls.add('requestEmailChange');
    await _maybeThrow(requestEmailChangeError);
    lastRequestedEmail = newEmail;
    lastEmailChangeToken = reauthenticationToken;
    return _accepted;
  }

  @override
  Future<AccountSessionsResponse> fetchSessions() async {
    calls.add('fetchSessions');
    await _maybeThrow(fetchSessionsError);
    return AccountSessionsResponse(
      schemaVersion: kSchemaVersion,
      sessions: List.unmodifiable(_sessions),
    );
  }

  @override
  Future<AccountSessionRevocationResponse> revokeSession(
    String sessionId,
  ) async {
    calls.add('revokeSession:$sessionId');
    await _maybeThrow(revokeSessionError);
    final removed = _sessions.where((s) => s.id == sessionId).length;
    _sessions.removeWhere((s) => s.id == sessionId);
    return AccountSessionRevocationResponse(
      schemaVersion: kSchemaVersion,
      revokedCount: removed,
      currentSessionRevoked: revokeSessionRevokesCurrent,
    );
  }

  @override
  Future<AccountSessionRevocationResponse> revokeSessions({
    required String scope,
  }) async {
    calls.add('revokeSessions:$scope');
    lastRevokeScope = scope;
    await _maybeThrow(revokeSessionsError);
    final removed = _sessions.where((s) => !s.current).length;
    _sessions.removeWhere((s) => !s.current);
    return AccountSessionRevocationResponse(
      schemaVersion: kSchemaVersion,
      revokedCount: removed,
      currentSessionRevoked: scope == 'all',
    );
  }

  @override
  Future<BlockedAccountsResponse> fetchBlockedAccounts() async {
    calls.add('fetchBlockedAccounts');
    await _maybeThrow(fetchBlockedAccountsError);
    return BlockedAccountsResponse(
      schemaVersion: kSchemaVersion,
      accounts: List.unmodifiable(_blockedAccounts),
    );
  }

  @override
  Future<AccountActionAcceptedResponse> unblockAccount(String userId) async {
    calls.add('unblockAccount:$userId');
    await _maybeThrow(unblockAccountError);
    _blockedAccounts.removeWhere((a) => a.id == userId);
    return _accepted;
  }

  @override
  Future<AccountDeletionSummaryResponse> fetchDeletionSummary() async {
    calls.add('fetchDeletionSummary');
    await _maybeThrow(fetchDeletionSummaryError);
    return _deletionSummary;
  }

  @override
  Future<AccountDeletionOperationResponse> deleteAccount({
    required String reauthenticationToken,
  }) async {
    calls.add('deleteAccount');
    await _maybeThrow(deleteAccountError);
    lastDeletionToken = reauthenticationToken;
    return const AccountDeletionOperationResponse(
      schemaVersion: kSchemaVersion,
      requestId: 'fake-deletion-request-0001',
      status: 'completed',
    );
  }

  /// `start`te istenen amaç; `complete` bunu AYNEN geri döner (gerçek
  /// sunucu da amaca bağlı token ürettiği için — bkz.
  /// `AccountReauthenticator`ın amaç-eşleşme kontrolü).
  AccountReauthenticationPurpose _lastPurpose =
      AccountReauthenticationPurpose.account_deletion;

  @override
  Future<AccountReauthenticationStartResponse> startReauthentication({
    required AccountReauthenticationPurpose purpose,
    required String redirectUri,
    required String codeChallenge,
  }) async {
    calls.add('startReauthentication:${purpose.name}');
    await _maybeThrow(startReauthenticationError);
    _lastPurpose = purpose;
    lastCodeChallenge = codeChallenge;
    return AccountReauthenticationStartResponse(
      schemaVersion: kSchemaVersion,
      requestId: 'fake-reauth-request-0001',
      authorizationUrl:
          'https://fake-identity.panelya.invalid/authorize?state=fake-state',
      callbackUrlScheme: 'panelya',
      expiresAt: '2030-01-01T12:05:00.000Z',
    );
  }

  @override
  Future<AccountReauthenticationCompleteResponse> completeReauthentication({
    required String requestId,
    required String authorizationCode,
    required String state,
    required String codeVerifier,
    required String redirectUri,
  }) async {
    calls.add('completeReauthentication');
    await _maybeThrow(completeReauthenticationError);
    lastCodeVerifier = codeVerifier;
    return AccountReauthenticationCompleteResponse(
      schemaVersion: kSchemaVersion,
      purpose: _lastPurpose,
      reauthenticationToken:
          'fake-reauthentication-token-0000000000000000000000',
      expiresAt: '2030-01-01T12:10:00.000Z',
    );
  }
}
