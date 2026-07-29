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
/// değiştirilecek).
///
/// !!! YAYIN ENGELİ (web tarafının açık talimatı) !!!
/// Bu sürüm main/release hattına ALINMAMALIDIR: [FakeAccountRepository]'nin
/// mutation'ları (profil kaydetme, e-posta değiştirme, şifre sıfırlama,
/// oturum kapatma, engel kaldırma, HESAP SİLME) hiçbir şey yapmadan
/// BAŞARILI görünür.
///
/// Bugünkü koruma DOLAYLIDIR ve TEK BİR BAYRAĞA bağlıdır: bu ekranlara
/// yalnız `AccountHomeScreen`in gezinme satırlarından ulaşılır, o da
/// `/account` üzerinden gelir, o da `discover_screen.dart`da
/// `AuthFeatureConfig.enabled` (`AUTH_ENABLED` dart-define, varsayılan
/// `false`) açıkken render edilir. Yani varsayılan/release derlemesinde
/// bu sahte mutation'lara ULAŞILAMAZ.
///
/// DİKKAT — bu korumanın kırılgan noktası: `AUTH_ENABLED` aynı anda hem
/// GERÇEK Auth0 girişini (artık hazır ve canlı doğrulanmış, bkz. ADR-039)
/// hem de bu SAHTE hesap mutation'larını açar. Gerçek girişi yayına almak
/// için bayrak `true` yapıldığı anda sahte mutation'lar da erişilebilir
/// hale gelir. Bu yüzden `AUTH_ENABLED=true` ile yayına çıkmadan ÖNCE ya
/// `HttpAccountRepository` tamamlanmalı ya da bu ekranlara giden yol ayrı
/// bir bayrakla kapatılmalıdır.
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
