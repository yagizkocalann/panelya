import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Hesabım" YÖNETİM ekranlarının (Profil, E-posta ve şifre, Aktif
/// oturumlar, Engellenen hesaplar, Hesabı sil — bkz. `features/account/`,
/// ADR-047) açma/kapama anahtarı.
///
/// `AuthFeatureConfig`ten (`AUTH_ENABLED`) KASITLI OLARAK AYRIDIR ve ondan
/// bağımsız değerlendirilir. Gerekçe: `AUTH_ENABLED` gerçek Auth0
/// giriş/çıkış/oturum davranışını kontrol eder ve bu artık HAZIRDIR (bkz.
/// ADR-039, canlı doğrulandı); hesap YÖNETİMİ ise henüz yalnız
/// presentation-only `FakeAccountRepository` üzerinde çalışır ve
/// mutation'ları (profil kaydetme, e-posta değiştirme, şifre sıfırlama,
/// oturum kapatma, engel kaldırma, hesap silme) hiçbir şey yapmadan
/// BAŞARILI görünür. Tek bir bayrak ikisini birlikte açsaydı, gerçek girişi
/// yayına almak için bayrağı `true` yapmak sahte hesap mutation'larını da
/// kullanıcıya açardı.
///
/// `enabled == false` (VARSAYILAN) iken:
/// - `AccountHomeScreen` yalnız GERÇEK oturum bilgisini (`authSessionProvider`
///   -> `AuthUser`) ve "Çıkış yap"ı gösterir; `accountRepositoryProvider`a
///   HİÇ DOKUNMAZ (bu yüzden sahte sağlayıcı etiketi de gösterilmez).
/// - Beş yönetim girişi HİÇ RENDER EDİLMEZ — devre dışı buton veya
///   "yakında" placeholder olarak DA gösterilmez (ADR-010).
/// - `/account/*` alt rotaları (deep-link/doğrudan navigasyon dahil)
///   router'da fail-closed biçimde `/account`a yönlendirilir (bkz.
///   `app/router/router.dart` -> `redirect`).
///
/// Production'da yalnız ortak `/api/account/*` sözleşmesi ve gerçek
/// `HttpAccountRepository` hazır olduğunda açılacaktır; bugün `true`
/// değeri yalnız presentation testleri/geliştirme önizlemesi içindir.
@immutable
class AccountManagementFeatureConfig {
  const AccountManagementFeatureConfig({required this.enabled});

  factory AccountManagementFeatureConfig.fromDartDefines() {
    return const AccountManagementFeatureConfig(
      enabled: bool.fromEnvironment('ACCOUNT_MANAGEMENT_ENABLED'),
    );
  }

  final bool enabled;
}

/// Aktif [AccountManagementFeatureConfig]. Testlerde `enabled: true` ile
/// override edilip yönetim ekranları doğrulanır; override edilmezse
/// varsayılan `false` kalır.
final accountManagementFeatureConfigProvider =
    Provider<AccountManagementFeatureConfig>(
      (ref) => AccountManagementFeatureConfig.fromDartDefines(),
    );
