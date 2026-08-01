import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Hesabım" YÖNETİM ekranlarının (Profil, E-posta ve şifre, Aktif
/// oturumlar, Engellenen hesaplar, Hesabı sil — bkz. `features/account/`,
/// ADR-047) açma/kapama anahtarı.
///
/// `AuthFeatureConfig`ten (`AUTH_ENABLED`) KASITLI OLARAK AYRIDIR ve ondan
/// bağımsız değerlendirilir.
///
/// Gerekçe artık "sahte mutation" DEĞİLDİR: hesap yönetimi gerçek
/// `HttpAccountRepository` ile ortak `/api/account/*` sözleşmesine bağlıdır
/// (bkz. ADR-047, OpenAPI 1.4.1) ve mutation'lar gerçekten sunucuya gider.
/// Bayrak bir YAYIN KAPISI olarak duruyor: hesap yönetimi geri alınamaz
/// aksiyonlar içerir (hesap silme) ve akışların bir kısmı henüz her iki
/// platformda da canlı doğrulanamadı — oturum envanteri ile şifre
/// yenileme, gerekli Auth0 Management/runtime değerleri o ortama
/// kurulmadan 503 fail-closed döner; hesap silme ise yalnız disposable bir
/// test hesabıyla çalıştırılabileceği için hiç denenmedi. Bu yüzden gerçek
/// girişi (`AUTH_ENABLED`) yayına almak, hesap yönetimini de otomatik
/// açmaz.
///
/// `enabled == false` (VARSAYILAN) iken:
/// - `AccountHomeScreen` yalnız GERÇEK oturum bilgisini (`authSessionProvider`
///   -> `AuthUser`) ve "Çıkış yap"ı gösterir; `accountRepositoryProvider`a
///   HİÇ DOKUNMAZ (bu yüzden sağlayıcı etiketi de gösterilmez).
/// - Beş yönetim girişi HİÇ RENDER EDİLMEZ — devre dışı buton veya
///   "yakında" placeholder olarak DA gösterilmez (ADR-010).
/// - `/account/*` alt rotaları (deep-link/doğrudan navigasyon dahil)
///   router'da fail-closed biçimde `/account`a yönlendirilir (bkz.
///   `app/router/router.dart` -> `redirect`).
///
/// Açılma koşulu: hedef ortamda gerekli Auth0 Management/runtime
/// değerleri kurulu olmalı (aksi hâlde oturum envanteri ve şifre yenileme
/// 503 döner) ve hesap silme akışı disposable bir test hesabıyla canlı
/// doğrulanmış olmalı. `true` değeri bugün geliştirme/QA turları içindir.
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
