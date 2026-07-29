import '../domain/account_deletion_summary.dart';
import '../domain/account_provider.dart';
import '../domain/account_repository.dart';
import '../domain/account_session.dart';
import '../domain/blocked_account.dart';

/// [AccountRepository]'nin in-memory sahte implementasyonu.
///
/// Bugün `accountRepositoryProvider` (bkz. `presentation/
/// account_providers.dart`) BUNU bağlar — gerçek bir `/api/account/*` HTTP
/// isteği henüz YOKTUR (bkz. `AccountRepository`'nin sınıf dokümantasyonu).
/// TODO(ADR-047): ortak `/api/account/*` JSON Schema/OpenAPI/fixture
/// sözleşmesi `main`e girip mobil token gateway'i hazır olduğunda,
/// `accountRepositoryProvider` bu sınıf yerine gerçek bir
/// `HttpAccountRepository` bağlayacak — çağıran kod (ekranlar) değişmeyecek.
///
/// Ayarlanabilir `Object?` hata alanları ve bir `calls` listesi taşır (bkz.
/// `features/auth/data/fake_auth_repository.dart` ile aynı desen) ki hem
/// canlı geliştirme/demo sırasında gerçekçi davransın hem de widget
/// testlerinde her senaryo (başarı/hata) tetiklenebilsin.
class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({
    this.provider = AccountProvider.database,
    List<AccountSession>? sessions,
    List<BlockedAccount>? blockedAccounts,
    AccountDeletionSummary? deletionSummary,
  }) : _sessions = List.of(sessions ?? _defaultSessions),
       _blockedAccounts = List.of(blockedAccounts ?? const []),
       _deletionSummary = deletionSummary ?? _defaultDeletionSummary;

  final AccountProvider provider;
  final List<AccountSession> _sessions;
  final List<BlockedAccount> _blockedAccounts;
  final AccountDeletionSummary _deletionSummary;

  /// Çağrı sırasını/sayısını doğrulamak için (bkz. testlerdeki
  /// `expect(repository.calls, [...])`).
  final List<String> calls = [];

  Object? fetchSignInProviderError;
  Object? updateProfileError;
  Object? requestEmailChangeError;
  Object? requestPasswordResetError;
  Object? listSessionsError;
  Object? revokeSessionError;
  Object? revokeOtherSessionsError;
  Object? listBlockedAccountsError;
  Object? unblockAccountError;
  Object? fetchDeletionSummaryError;
  Object? deleteAccountError;

  String? lastUpdatedDisplayName;
  String? lastRequestedEmail;
  String? lastAcceptedReauthCredential;

  static final List<AccountSession> _defaultSessions = [
    AccountSession(
      id: 's-current',
      deviceLabel: 'Bu cihaz — Android',
      platform: AccountSessionPlatform.android,
      lastActiveAt: DateTime(2026, 7, 23, 9),
      isCurrentDevice: true,
    ),
    AccountSession(
      id: 's-web',
      deviceLabel: 'Chrome — Windows',
      platform: AccountSessionPlatform.web,
      lastActiveAt: DateTime(2026, 7, 20, 14, 30),
      isCurrentDevice: false,
    ),
  ];

  static const _defaultDeletionSummary = AccountDeletionSummary(
    deletedItems: ['Profil bilgilerin', 'Auth0 kimliğin', 'Aktif oturumların'],
    anonymizedItems: ['Yorumların', 'Topluluk katkıların'],
  );

  Future<void> _maybeThrow(Object? error) async {
    if (error != null) Error.throwWithStackTrace(error, StackTrace.current);
  }

  @override
  Future<AccountProvider> fetchSignInProvider() async {
    calls.add('fetchSignInProvider');
    await _maybeThrow(fetchSignInProviderError);
    return provider;
  }

  @override
  Future<void> updateProfile({required String displayName}) async {
    calls.add('updateProfile');
    await _maybeThrow(updateProfileError);
    lastUpdatedDisplayName = displayName;
  }

  @override
  Future<void> requestEmailChange({required String newEmail}) async {
    calls.add('requestEmailChange');
    await _maybeThrow(requestEmailChangeError);
    lastRequestedEmail = newEmail;
  }

  @override
  Future<void> requestPasswordReset() async {
    calls.add('requestPasswordReset');
    await _maybeThrow(requestPasswordResetError);
  }

  @override
  Future<List<AccountSession>> listSessions() async {
    calls.add('listSessions');
    await _maybeThrow(listSessionsError);
    return List.unmodifiable(_sessions);
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    calls.add('revokeSession:$sessionId');
    await _maybeThrow(revokeSessionError);
    _sessions.removeWhere((session) => session.id == sessionId);
  }

  @override
  Future<void> revokeOtherSessions() async {
    calls.add('revokeOtherSessions');
    await _maybeThrow(revokeOtherSessionsError);
    _sessions.removeWhere((session) => !session.isCurrentDevice);
  }

  @override
  Future<List<BlockedAccount>> listBlockedAccounts() async {
    calls.add('listBlockedAccounts');
    await _maybeThrow(listBlockedAccountsError);
    return List.unmodifiable(_blockedAccounts);
  }

  @override
  Future<void> unblockAccount(String blockedAccountId) async {
    calls.add('unblockAccount:$blockedAccountId');
    await _maybeThrow(unblockAccountError);
    _blockedAccounts.removeWhere((account) => account.id == blockedAccountId);
  }

  @override
  Future<AccountDeletionSummary> fetchDeletionSummary() async {
    calls.add('fetchDeletionSummary');
    await _maybeThrow(fetchDeletionSummaryError);
    return _deletionSummary;
  }

  @override
  Future<void> deleteAccount({required String reauthCredential}) async {
    calls.add('deleteAccount');
    await _maybeThrow(deleteAccountError);
    lastAcceptedReauthCredential = reauthCredential;
  }
}
