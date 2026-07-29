import 'account_deletion_summary.dart';
import 'account_provider.dart';
import 'account_session.dart';
import 'blocked_account.dart';

/// "Hesabım" sınırının tek soyut sözleşmesi (bkz. ADR-047).
///
/// PROVISIONAL: web tarafının ortak `/api/account/*` JSON Schema/OpenAPI/
/// fixture sözleşmesi `main`e girene kadar bu arayüz elle tasarlanmıştır;
/// gerçek sözleşme geldiğinde metot imzaları/dönüş tipleri değişebilir.
/// Bugün yalnız `FakeAccountRepository` (bkz. `data/
/// fake_account_repository.dart`) bağlanır — GERÇEK bir `/api/account/*`
/// HTTP isteği YOKTUR (bkz. görev talimatı: mobil bunu şimdi yazmayacak,
/// `/api/auth/mobile/*` yalnız OAuth code/refresh/revoke taşır, hesap
/// uçları web ile AYNI `/api/account/*` sözleşmesini paylaşacak — ayrı bir
/// `/api/account/mobile/*` AÇILMAYACAK).
///
/// "Taze kimlik doğrulaması" gerektiren [deleteAccount] KASITLI OLARAK
/// `AuthBrowser`'a bağımlı DEĞİLDİR (bkz. `features/auth/data/
/// auth_browser.dart`) — bu, `AuthRepository`'nin de kendi çağıranından
/// (`AccountScreen`/`DeleteAccountScreen`) `AuthBrowser`'ı ayrı tutmasıyla
/// aynı katman sınırını korur. Çağıran (`DeleteAccountScreen`) taze kimlik
/// doğrulamasını KENDİSİ `authRepositoryProvider.beginSignIn()` +
/// `authBrowserProvider.authenticate()` ile elde eder, sonucu opak bir
/// `reauthCredential` olarak buraya geçirir.
abstract class AccountRepository {
  /// Kullanıcının Auth0'a hangi sağlayıcıyla giriş yaptığı (bkz.
  /// `AccountOverview`, `account_providers.dart` -> `accountOverviewProvider`).
  Future<AccountProvider> fetchSignInProvider();

  /// Görünen adı günceller (bkz. "Profil" ekranı).
  Future<void> updateProfile({required String displayName});

  /// E-posta değiştirme isteği başlatır (bkz. ADR-047: yalnız
  /// [AccountProvider.database] sağlayıcısında anlamlıdır — çağıran bunu
  /// [AccountProviderX.supportsEmailChange] ile önceden kontrol eder).
  Future<void> requestEmailChange({required String newEmail});

  /// Şifre sıfırlama e-postası gönderir (bkz. ADR-047: yalnız
  /// [AccountProvider.database] sağlayıcısında anlamlıdır). Uygulama
  /// içinde eski/yeni şifre alanı HİÇBİR ZAMAN OLUŞTURULMAZ — bu metot
  /// yalnız bir e-posta tetikler.
  Future<void> requestPasswordReset();

  /// Aktif oturumları listeler (bkz. "Aktif oturumlar" ekranı).
  Future<List<AccountSession>> listSessions();

  /// Tek bir oturumu kapatır. [sessionId] mevcut cihazın oturumuysa,
  /// çağıran (`SessionsScreen`) bunun ardından yerel oturumu da
  /// (`authRepositoryProvider.logout()`) temizlemekten SORUMLUDUR — bu
  /// metodun kendisi yerel `TokenStore`'a dokunmaz.
  Future<void> revokeSession(String sessionId);

  /// Mevcut cihaz HARİÇ tüm oturumları kapatır.
  Future<void> revokeOtherSessions();

  /// Engellenen hesapları listeler.
  Future<List<BlockedAccount>> listBlockedAccounts();

  /// Bir hesabın engelini kaldırır.
  Future<void> unblockAccount(String blockedAccountId);

  /// "Hesabı sil" ekranının gösterdiği, neyin silinip neyin
  /// anonimleştirileceğine dair özeti getirir.
  Future<AccountDeletionSummary> fetchDeletionSummary();

  /// Hesabı kalıcı olarak siler: Panelya kullanıcısını, Auth0 kimliğini VE
  /// aktif oturumları kapsar (bkz. ADR-047 — yalnız yerel `users` satırı
  /// değil).
  ///
  /// [reauthCredential]: çağıranın (`DeleteAccountScreen`) sistem
  /// tarayıcısında taze bir Auth0 oturumu açıp elde ettiği opak kanıt (bkz.
  /// bu sınıfın dokümantasyonu). Sağlayıcı bunu geçersiz/süresi dolmuş
  /// bulursa [AccountReauthRequiredException] fırlatır.
  Future<void> deleteAccount({required String reauthCredential});
}
