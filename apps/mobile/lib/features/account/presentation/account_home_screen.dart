import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/config/account_management_feature_config.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/domain/auth_session_state.dart';
import '../../auth/presentation/auth_providers.dart';
import 'account_avatar.dart';
import 'account_capability_view.dart';
import 'account_error_message.dart';
import 'account_providers.dart';

/// "Hesabım ana ekranı" (bkz. ADR-047): avatar/görünen ad, e-posta +
/// doğrulanma durumu, giriş sağlayıcısı ve Profil/E-posta ve şifre/Aktif
/// oturumlar/Engellenen hesaplar/Hesabı sil/Çıkış yap'a giden gezinme
/// satırları.
///
/// İKİ AYRI MOD (bkz. [AccountManagementFeatureConfig]):
/// - Bayrak KAPALI (varsayılan): yalnız GERÇEK oturum bilgisi
///   (`authSessionProvider` -> `AuthUser`) ve "Çıkış yap" gösterilir.
///   [accountRepositoryProvider]a (ve dolayısıyla sahte veriye) HİÇ
///   DOKUNULMAZ — bu yüzden sağlayıcı etiketi de gösterilmez, çünkü o
///   bilgi yalnız hesap repository'sinden gelir. Beş yönetim girişi HİÇ
///   RENDER EDİLMEZ: devre dışı buton veya "yakında" placeholder olarak DA
///   gösterilmez (ADR-010).
/// - Bayrak AÇIK (bugün yalnız presentation testleri/geliştirme
///   önizlemesi): ek olarak sağlayıcı etiketi ve beş yönetim girişi
///   gösterilir; bunlar [accountOverviewProvider] üzerinden okunur.
///
/// Kendi `Scaffold`'unu OLUŞTURMAZ — `AccountScreen`'in (bkz.
/// `features/auth/presentation/account_screen.dart`) `AuthAuthenticated`
/// dalına gömülür; AppBar/HomeButton/SafeArea zaten oradan gelir.
class AccountHomeScreen extends ConsumerStatefulWidget {
  const AccountHomeScreen({super.key});

  @override
  ConsumerState<AccountHomeScreen> createState() => _AccountHomeScreenState();
}

class _AccountHomeScreenState extends ConsumerState<AccountHomeScreen> {
  bool _signOutBusy = false;

  /// Çıkış yapar. Hata fırlasa bile [_signOutBusy] `finally` ile MUTLAKA
  /// sıfırlanır: aksi hâlde buton kalıcı olarak spinner'da kilitlenir ve
  /// kullanıcı ne çıkış yapabilir ne tekrar deneyebilirdi.
  ///
  /// Sunucu revoke'unun başarısızlığı buraya ULAŞMAZ (bkz.
  /// `HttpAuthRepository.logout` — ADR-039 gereği yutulur). Buraya ancak
  /// YEREL temizlik gerçekten başarısız olduğunda bir hata gelir; o
  /// durumda kullanıcı hâlâ giriş yapmış sayılır, bu yüzden sahte başarı
  /// göstermeyip dürüst bir mesaj veririz (ADR-010).
  Future<void> _signOut() async {
    setState(() => _signOutBusy = true);
    try {
      await ref.read(authRepositoryProvider).logout();
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Çıkış yapılamadı. Tekrar dene.')),
      );
    } finally {
      if (mounted) setState(() => _signOutBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final managementEnabled = ref
        .watch(accountManagementFeatureConfigProvider)
        .enabled;

    if (!managementEnabled) {
      // Hesap yönetimi kapalı: gerçek oturum kullanıcısını doğrudan
      // `authSessionProvider`dan okuruz — `accountRepositoryProvider` HİÇ
      // okunmaz. Böylece bayrak kapalıyken `GET /api/account` isteği bile
      // gitmez; ekran yalnız elde zaten bulunan oturum bilgisini gösterir.
      final session = ref.watch(authSessionProvider);
      final user = switch (session) {
        AuthAuthenticated(:final user) => user,
        // `AccountScreen` bu widget'ı yalnız kimliği doğrulanmışken
        // gösterir; bu dal yalnız savunma amaçlıdır (sahte bir kimlik
        // ÜRETİLMEZ, boş bırakılır).
        AuthAnonymous() => null,
      };
      if (user == null) return const SizedBox.shrink();
      return _AccountHomeBody(
        user: user,
        providerLabel: null,
        capabilities: null,
        busy: _signOutBusy,
        onSignOut: _signOut,
      );
    }

    final overview = ref.watch(accountOverviewProvider);
    return overview.when(
      loading: () => const AppLoadingView(label: 'Hesap bilgilerin yükleniyor'),
      error: (error, stackTrace) => AppErrorView(
        message: accountErrorMessage(error),
        onRetry: () => ref.invalidate(accountOverviewProvider),
      ),
      data: (overview) => _AccountHomeBody(
        user: overview.user,
        providerLabel: _providerLabel(overview.provider),
        capabilities: overview.capabilities,
        busy: _signOutBusy,
        onSignOut: _signOut,
      ),
    );
  }

  static String _providerLabel(AccountProviderKind provider) =>
      switch (provider) {
        AccountProviderKind.database => 'E-posta ve şifre ile giriş yaptın.',
        AccountProviderKind.google => 'Google ile giriş yaptın.',
        AccountProviderKind.other_social => 'Bir sosyal hesapla giriş yaptın.',
        // İleri-uyumluluk fallback'i: bu istemcinin bilmediği yeni bir
        // sağlayıcı geldiğinde yanlış bir etiket UYDURULMAZ.
        AccountProviderKind.unknown =>
          'Bir kimlik sağlayıcısıyla giriş yaptın.',
      };
}

class _AccountHomeBody extends StatelessWidget {
  const _AccountHomeBody({
    required this.user,
    required this.providerLabel,
    required this.capabilities,
    required this.busy,
    required this.onSignOut,
  });

  final AuthUser user;
  final String? providerLabel;

  /// `null` ise hesap yönetimi KAPALIDIR (bkz.
  /// [AccountManagementFeatureConfig]) ve hiçbir yönetim girişi
  /// gösterilmez. Doluysa her giriş kendi yeteneğine göre gösterilir —
  /// yeteneği `unavailable`/`unknown` olan satır HİÇ render edilmez
  /// (ADR-010: devre dışı buton/placeholder yok).
  final AccountCapabilities? capabilities;
  final bool busy;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return ListView(
      padding: EdgeInsets.all(tokens.spacing.md),
      children: [
        Center(
          child: Column(
            children: [
              AccountAvatar(user: user),
              SizedBox(height: tokens.spacing.sm),
              Text(
                user.displayName,
                style: tokens.typography.titleMedium,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: tokens.spacing.xs),
              // `container: true` + `ExcludeSemantics` OLMADAN bu etiket ekran
              // okuyucuya HİÇ ULAŞMAZ: `Semantics(label:)` tek başına yeni bir
              // düğüm oluşturmaz, çocukların (metin + ikon) kendi semantiği
              // geçerli olur ve ikonun `semanticLabel`ı olmadığı için
              // doğrulama durumu sessizce kaybolurdu. Bu ikisiyle e-posta ve
              // rozet TEK bir düğüm olarak, durumu da söyleyerek okunur.
              // GÖRSEL davranış değişmez (bkz. `SecurityScreen`'deki eşi).
              Semantics(
                container: true,
                label: user.emailVerified
                    ? '${user.email}, doğrulanmış'
                    : '${user.email}, doğrulanmamış',
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          user.email,
                          style: tokens.typography.bodySmall.copyWith(
                            color: tokens.colors.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: tokens.spacing.xs),
                      Icon(
                        user.emailVerified
                            ? Icons.verified_outlined
                            : Icons.error_outline,
                        size: 16,
                        color: user.emailVerified
                            ? tokens.colors.mint
                            : tokens.colors.coral,
                      ),
                    ],
                  ),
                ),
              ),
              if (providerLabel != null) ...[
                SizedBox(height: tokens.spacing.xs),
                Text(
                  providerLabel!,
                  style: tokens.typography.bodySmall.copyWith(
                    color: tokens.colors.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.lg),
        // Her giriş kendi YETENEĞİNE göre gösterilir. "Profil" satırı
        // profil düzenleme VEYA e-posta/şifre yeteneklerinden biri
        // kullanılabilirse anlamlıdır; e-posta/şifre ekranı kendi içinde
        // ayrıca `provider_managed` durumunu açıklayıcı metinle ele alır
        // (bkz. `security_screen.dart`), bu yüzden o satır
        // `provider_managed`da da gösterilir.
        ...?_managementRows(context, tokens),
        if (busy)
          const Center(child: CircularProgressIndicator())
        else
          Center(
            child: OutlinedButton(
              onPressed: onSignOut,
              child: const Text('Çıkış yap'),
            ),
          ),
      ],
    );
  }

  /// Yönetim girişleri. [capabilities] `null` ise (bayrak kapalı) `null`
  /// döner — hiçbir satır render edilmez.
  List<Widget>? _managementRows(BuildContext context, AppTokens tokens) {
    final capabilities = this.capabilities;
    if (capabilities == null) return null;

    // "E-posta ve şifre" ekranı, `provider_managed` durumunda AÇIKLAYICI
    // metin gösterdiği için o durumda da erişilebilir olmalı; yalnız
    // ikisi de tamamen kullanılamazsa satır gizlenir.
    final securityReachable =
        capabilities.emailChange.isActionable ||
        capabilities.passwordAction.isActionable ||
        capabilities.emailChange.isProviderManaged ||
        capabilities.passwordAction.isProviderManaged;

    final rows = <Widget>[
      if (capabilities.profileEditing.isActionable)
        _AccountNavRow(
          icon: Icons.person_outline,
          label: 'Profil',
          onTap: () => context.push('/account/profile'),
        ),
      if (securityReachable)
        _AccountNavRow(
          icon: Icons.lock_outline,
          label: 'E-posta ve şifre',
          onTap: () => context.push('/account/security'),
        ),
      if (capabilities.sessionManagement.isActionable)
        _AccountNavRow(
          icon: Icons.devices_outlined,
          label: 'Aktif oturumlar',
          onTap: () => context.push('/account/sessions'),
        ),
      if (capabilities.blockedAccounts.isActionable)
        _AccountNavRow(
          icon: Icons.block_outlined,
          label: 'Engellenen hesaplar',
          onTap: () => context.push('/account/blocked'),
        ),
      if (capabilities.accountDeletion.isActionable)
        _AccountNavRow(
          icon: Icons.delete_forever_outlined,
          label: 'Hesabı sil',
          iconColor: tokens.colors.coral,
          labelColor: tokens.colors.coral,
          onTap: () => context.push('/account/delete'),
        ),
    ];
    if (rows.isEmpty) return null;

    // Satırların ARASINA ayırıcı koyar (sonuna koymaz).
    final withDividers = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        withDividers.add(Divider(color: tokens.colors.line, height: 1));
      }
      withDividers.add(rows[i]);
    }
    return [...withDividers, SizedBox(height: tokens.spacing.lg)];
  }
}

/// "Hesabım" ana ekranındaki gezinme satırlarının ortak, erişilebilir
/// şekli (bkz. `features/offline/presentation/downloads_screen.dart` ->
/// `_DownloadedEpisodeTile` ile aynı `Semantics(button: true)` + `InkWell`
/// + minimum dokunma yüksekliği deseni).
class _AccountNavRow extends StatelessWidget {
  const _AccountNavRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: tokens.sizes.minTouchTarget),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.md,
              vertical: tokens.spacing.sm,
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor ?? tokens.colors.ink),
                SizedBox(width: tokens.spacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: tokens.typography.bodyMedium.copyWith(
                      color: labelColor ?? tokens.colors.ink,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: tokens.colors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
