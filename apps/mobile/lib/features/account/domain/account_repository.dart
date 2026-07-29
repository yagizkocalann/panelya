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
/// TAZE KİMLİK DOĞRULAMASI — MEVCUT İMZA GEÇİCİDİR, DEĞİŞECEK:
///
/// Bugünkü [deleteAccount] imzası (`reauthCredential` olarak callback'ten
/// alınan Auth0 authorization `code`'unu geçirmek) YALNIZ presentation-only
/// `FakeAccountRepository` demosu içindir. Web tarafı bu zinciri açıkça
/// REDDETTİ: Auth0 authorization code'u gerçek bir hesap mutation'ına
/// DOĞRUDAN VERİLMEYECEK.
///
/// Ortak sözleşmenin tanımlayacağı gerçek akış (web tarafından iletildi):
/// 1. `POST /api/account/reauthentication/start`
/// 2. Sistem tarayıcısında `max_age=0` + PKCE ile doğrulama
/// 3. `POST /api/account/reauthentication/complete`
/// 4. Sunucudan AMACA BAĞLI, kısa ömürlü, TEK KULLANIMLIK
///    `reauthenticationToken`
/// 5. E-posta değiştirme/hesap silme mutation'ında bu token kullanılır
///
/// Bu akış mevcut `AuthRepository` oturumunu ve `TokenStore`'u
/// DEĞİŞTİRMEYECEK. Sözleşme/schema/OpenAPI/fixture `main`e girdiğinde bu
/// arayüzün imzası (ve `DeleteAccountScreen`'in orkestrasyonu) buna göre
/// güncellenecek — o zamana kadar aşağıdaki `reauthCredential` parametresi
/// bir YER TUTUCUdur, gerçek güvenlik sınırını temsil etmez.
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
  /// [reauthCredential]: GEÇİCİ yer tutucu — bkz. bu sınıfın "TAZE KİMLİK
  /// DOĞRULAMASI" notu. Gerçek sözleşmede bunun yerine sunucudan alınan,
  /// amaca bağlı ve tek kullanımlık bir `reauthenticationToken` gelecek.
  /// Sağlayıcı bunu geçersiz/süresi dolmuş bulursa
  /// [AccountReauthRequiredException] fırlatır.
  Future<void> deleteAccount({required String reauthCredential});
}
