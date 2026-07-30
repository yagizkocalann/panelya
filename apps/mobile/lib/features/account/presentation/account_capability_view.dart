import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/contracts/generated/generated.dart';

/// Bir [AccountActionCapability] değerinin ekranda nasıl karşılanacağını
/// tek noktada tanımlar (bkz. ADR-047 capability sözleşmesi).
///
/// ADR-010 gereği hiçbir durumda "görünen ama çalışmayan" bir kontrol
/// üretilmez:
/// - `enabled` / `reauthentication_required` -> aksiyon GERÇEKTEN
///   gösterilir (ikincisi tetiklendiğinde önce taze kimlik doğrulaması
///   yapılır, bkz. `AccountReauthenticator`).
/// - `provider_managed` -> aksiyon YERİNE, etkileşimsiz açıklayıcı metin
///   ([AccountCapabilityNotice]) gösterilir; devre dışı buton GÖSTERİLMEZ.
/// - `unavailable` -> aksiyon HİÇ gösterilmez (opsiyonel olarak kısa bir
///   açıklama metni gösterilebilir).
/// - `unknown` -> ileri-uyumluluk fallback'i; bu istemcinin bilmediği bir
///   değer geldiğinde GÜVENLİ tarafta kalınır ve aksiyon gösterilmez
///   (`unavailable` gibi ele alınır).
extension AccountActionCapabilityX on AccountActionCapability {
  /// Aksiyon (buton/form) gerçekten render edilmeli mi.
  bool get isActionable =>
      this == AccountActionCapability.enabled ||
      this == AccountActionCapability.reauthentication_required;

  /// Aksiyon tetiklendiğinde önce taze kimlik doğrulaması gerekiyor mu.
  bool get needsReauthentication =>
      this == AccountActionCapability.reauthentication_required;

  /// Sağlayıcı (ör. Google) tarafından yönetiliyor — kullanıcıya nedenini
  /// açıklayan etkileşimsiz bir not gösterilir.
  bool get isProviderManaged =>
      this == AccountActionCapability.provider_managed;
}

/// Bir yeteneğin neden kullanılamadığını anlatan, ETKİLEŞİMSİZ bilgi
/// metni. Devre dışı bir buton veya "yakında" placeholder DEĞİLDİR
/// (ADR-010) — yalnız metindir, dokunma hedefi yoktur.
class AccountCapabilityNotice extends StatelessWidget {
  const AccountCapabilityNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: EdgeInsets.all(tokens.spacing.sm),
      decoration: BoxDecoration(
        color: tokens.colors.surface2,
        borderRadius: BorderRadius.circular(tokens.radii.sm),
        border: Border.all(color: tokens.colors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: tokens.colors.muted),
          SizedBox(width: tokens.spacing.sm),
          Expanded(
            child: Text(
              message,
              style: tokens.typography.bodySmall.copyWith(
                color: tokens.colors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sözleşmenin `AccountSessionPlatform` değerini kullanıcıya gösterilecek
/// ikona çevirir. `unspecified` (sunucu platformu çıkaramadı) ile
/// `unknown` (bu istemcinin bilmediği yeni bir değer) BİLEREK aynı
/// ikonu paylaşır ama anlamları farklıdır (bkz. sözleşme açıklaması).
IconData accountSessionPlatformIcon(AccountSessionPlatform platform) =>
    switch (platform) {
      AccountSessionPlatform.web => Icons.language,
      AccountSessionPlatform.android => Icons.phone_android,
      AccountSessionPlatform.ios => Icons.phone_iphone,
      AccountSessionPlatform.unspecified => Icons.devices_other,
      AccountSessionPlatform.unknown => Icons.devices_other,
    };

/// Sözleşmenin `AccountDeletionEffect` değerlerini kullanıcıya gösterilecek
/// Türkçe metne çevirir. `unknown` (ileri-uyumluluk fallback'i) sessizce
/// atlanmaz — dürüstçe "bilinmeyen bir veri türü" olarak gösterilir ki
/// kullanıcı eksik bilgiyle silme onayı vermesin.
String accountDeletionEffectLabel(AccountDeletionEffect effect) =>
    switch (effect) {
      AccountDeletionEffect.auth_identity => 'Kimlik bilgilerin (Auth0)',
      AccountDeletionEffect.profile => 'Profil bilgilerin',
      AccountDeletionEffect.active_sessions => 'Aktif oturumların',
      AccountDeletionEffect.library => 'Kütüphanen',
      AccountDeletionEffect.reading_progress => 'Okuma ilerlemen',
      AccountDeletionEffect.block_relationships => 'Engelleme listen',
      AccountDeletionEffect.community_contributions => 'Topluluk katkıların',
      AccountDeletionEffect.legal_and_audit_records =>
        'Yasal kayıtlar ve denetim izleri',
      AccountDeletionEffect.unknown =>
        'Bu uygulama sürümünün tanımadığı bir veri türü',
    };
