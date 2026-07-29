import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_session_state.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/fake_account_repository.dart';
import '../domain/account_deletion_summary.dart';
import '../domain/account_exceptions.dart';
import '../domain/account_overview.dart';
import '../domain/account_repository.dart';
import '../domain/account_session.dart';
import '../domain/blocked_account.dart';

/// Aktif [AccountRepository]. Bugün yalnız [FakeAccountRepository]'yi
/// bağlar (bkz. o dosyadaki sınıf dokümantasyonu — TODO(ADR-047): gerçek
/// `/api/account/*` sözleşmesi gelince `HttpAccountRepository` ile
/// değiştirilecek, çağıran ekranlar değişmeyecek).
final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => FakeAccountRepository(),
);

/// "Hesabım" ana ekranının gösterdiği birleşik kimlik özeti.
///
/// Gerçek oturum kullanıcısını (`authSessionProvider`'dan) sağlayıcı
/// bilgisiyle (`accountRepositoryProvider`'dan) birleştirir (bkz.
/// `AccountOverview`'in sınıf dokümantasyonu) — bağlantısız/sahte bir
/// kimlik asla üretilmez, yalnız gerçek [AuthAuthenticated] durumu
/// sarmalanır. Oturum anonimse [AccountNotAuthenticatedException]
/// fırlatır (bu ekranlar zaten yalnız kimliği doğrulanmışken erişilebilir
/// olduğu için pratikte tetiklenmez, bkz. `AccountScreen`).
final accountOverviewProvider = FutureProvider<AccountOverview>((ref) async {
  final session = ref.watch(authSessionProvider);
  final user = switch (session) {
    AuthAuthenticated(:final user) => user,
    AuthAnonymous() => throw const AccountNotAuthenticatedException(),
  };
  final provider = await ref
      .watch(accountRepositoryProvider)
      .fetchSignInProvider();
  return AccountOverview(user: user, provider: provider);
});

/// Aktif oturumlar listesi (bkz. "Aktif oturumlar" ekranı). Mutasyonlar
/// (`revokeSession`/`revokeOtherSessions`) sonrası çağıran bu provider'ı
/// `ref.invalidate(...)` ile geçersiz kılar (bkz.
/// `offline_providers.dart` -> `downloadedEpisodesProvider` ile aynı desen
/// — ayrı bir `AsyncNotifier` kullanılmaz).
final accountSessionsProvider = FutureProvider<List<AccountSession>>(
  (ref) => ref.watch(accountRepositoryProvider).listSessions(),
);

/// Engellenen hesaplar listesi (bkz. "Engellenen hesaplar" ekranı).
final blockedAccountsProvider = FutureProvider<List<BlockedAccount>>(
  (ref) => ref.watch(accountRepositoryProvider).listBlockedAccounts(),
);

/// "Hesabı sil" ekranının gösterdiği silme/anonimleştirme özeti.
final accountDeletionSummaryProvider = FutureProvider<AccountDeletionSummary>(
  (ref) => ref.watch(accountRepositoryProvider).fetchDeletionSummary(),
);
