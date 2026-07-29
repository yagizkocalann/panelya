import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/account_management_feature_config.dart';
import '../../auth/domain/auth_session_state.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/fake_account_repository.dart';
import '../domain/account_deletion_summary.dart';
import '../domain/account_exceptions.dart';
import '../domain/account_overview.dart';
import '../domain/account_repository.dart';
import '../domain/account_session.dart';
import '../domain/blocked_account.dart';

/// Aktif [AccountRepository].
///
/// BİLEREK HİÇBİR VARSAYILAN BAĞLANTISI YOKTUR — okunduğunda
/// [UnimplementedError] fırlatır. Gerekçe (web tarafının açık talimatı):
/// [FakeAccountRepository] gerçek debug/release runtime'ının varsayılan
/// repository bağlantısı OLMAMALIDIR, çünkü mutation'ları (profil
/// kaydetme, e-posta değiştirme, şifre sıfırlama, oturum kapatma, engel
/// kaldırma, HESAP SİLME) hiçbir şey yapmadan BAŞARILI görünür. Sessizce
/// sahte başarı göstermek yerine, yanlışlıkla gerçek bir derlemede
/// okunursa GÜRÜLTÜLÜ biçimde patlar (fail-closed).
///
/// Bu provider yalnız şu iki durumda override edilir:
/// - Testlerde ([FakeAccountRepository] veya test-yerel sahtelerle),
/// - Açıkça seçilmiş bir geliştirme önizlemesinde
///   (`ACCOUNT_MANAGEMENT_ENABLED=true` + bir `ProviderScope` override'ı).
///
/// Normal çalışmada buraya HİÇ ULAŞILMAZ: hesap yönetimi ekranları
/// [AccountManagementFeatureConfig] (varsayılan `false`) kapalıyken hem
/// `AccountHomeScreen`de render edilmez hem router'da fail-closed
/// yönlendirilir; `AccountHomeScreen`in kapalı-bayrak yolu bu provider'ı
/// (ve dolayısıyla [accountOverviewProvider]'ı) hiç okumaz.
///
/// TODO(ADR-047): ortak `/api/account/*` sözleşmesi ve reauthentication
/// akışı `main`e girdiğinde burada gerçek `HttpAccountRepository`
/// bağlanacak.
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  throw UnimplementedError(
    'accountRepositoryProvider bağlanmadı: hesap yönetimi henüz yalnız '
    'presentation-only FakeAccountRepository üzerinde çalışıyor ve gerçek '
    'runtime\'a BİLEREK bağlanmamıştır (bkz. bu provider\'ın '
    'dokümantasyonu, ADR-047). Ortak /api/account/* sözleşmesi gelince '
    'HttpAccountRepository bağlanacak; o zamana kadar bu provider yalnız '
    'testlerde veya açık bir geliştirme önizlemesinde override edilir.',
  );
});

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
