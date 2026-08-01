import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../../shared/widgets/home_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/account_exceptions.dart';
import 'account_capability_view.dart';
import 'account_error_message.dart';
import 'account_providers.dart';

/// "E-posta ve şifre" ekranı (`/account/security`, bkz. ADR-047).
///
/// Hangi aksiyonun gösterileceğine SAĞLAYICI TÜRÜNE göre değil, sunucudan
/// gelen YETENEKLERE ([AccountCapabilities]) göre karar verir:
/// - `enabled` / `reauthentication_required` -> aksiyon gerçekten
///   gösterilir. E-posta değiştirme `reauthentication_required` ise,
///   gönderimden ÖNCE sistem tarayıcısında taze kimlik doğrulaması yapılır
///   (bkz. `AccountReauthenticator`) ve dönen tek kullanımlık
///   `reauthenticationToken` mutation'a geçirilir.
/// - `provider_managed` -> aksiyon YERİNE etkileşimsiz açıklama gösterilir
///   (devre dışı buton/form YOK, ADR-010).
/// - `unavailable`/`unknown` -> HİÇ gösterilmez: ne form, ne buton, ne
///   devre dışı placeholder, ne de "yakında" satırı.
///
/// ÜRÜN KARARI (web, 1 Ağustos 2026): e-posta değiştirme şimdilik
/// kullanıcıya açık "Hesabım" kapsamından çıkarıldı. Sunucu bu yeteneği
/// `unavailable` döndürdüğünde bu ekran yalnız SALT OKUNUR e-postayı ve
/// doğrulama durumunu gösterir; şifre aksiyonu bundan bağımsız çalışır.
/// `requestEmailChange` repository metodu ve üretilen DTO'lar bilinçli
/// olarak KORUNMUŞTUR — ortak sözleşme değişmedi, yalnız görünür ürün
/// yeteneği kapatıldı; karar geri alınırsa ekran kodu hazırdır.
///
/// Uygulama içinde eski/yeni şifre alanı HİÇBİR ZAMAN oluşturulmaz; şifre
/// aksiyonu yalnız bir e-posta tetikler.
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  final _newEmailController = TextEditingController();
  bool _emailChangeBusy = false;
  bool _emailChangeSucceeded = false;
  bool _passwordResetBusy = false;
  bool _passwordResetSucceeded = false;

  @override
  void dispose() {
    _newEmailController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _requestEmailChange({required bool needsReauth}) async {
    setState(() {
      _emailChangeBusy = true;
      _emailChangeSucceeded = false;
    });
    try {
      // Taze kimlik doğrulaması: authorization code mutation'a ASLA
      // doğrudan verilmez — sunucudan amaca bağlı, tek kullanımlık bir
      // token alınır (bkz. `AccountReauthenticator`).
      var token = '';
      if (needsReauth) {
        token = await ref
            .read(accountReauthenticatorProvider)
            .obtainToken(AccountReauthenticationPurpose.email_change);
      }
      await ref
          .read(accountRepositoryProvider)
          .requestEmailChange(
            newEmail: _newEmailController.text.trim(),
            reauthenticationToken: token,
          );
      if (mounted) setState(() => _emailChangeSucceeded = true);
    } on AccountReauthenticationCancelledException {
      // Kullanıcı taze kimlik doğrulamasını iptal etti — hata gösterilmez.
    } on AccountRepositoryException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _emailChangeBusy = false);
    }
  }

  Future<void> _requestPasswordReset() async {
    setState(() {
      _passwordResetBusy = true;
      _passwordResetSucceeded = false;
    });
    try {
      await ref.read(accountRepositoryProvider).requestPasswordReset();
      if (mounted) setState(() => _passwordResetSucceeded = true);
    } on AccountRepositoryException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _passwordResetBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(accountOverviewProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('E-posta ve şifre'),
        actions: const [HomeButton()],
      ),
      body: SafeArea(
        child: overview.when(
          loading: () => const AppLoadingView(label: 'Yükleniyor'),
          error: (error, stackTrace) => AppErrorView(
            message: accountErrorMessage(error),
            onRetry: () => ref.invalidate(accountOverviewProvider),
          ),
          data: (overview) => _SecurityBody(
            capabilities: overview.capabilities,
            currentEmail: overview.user.email,
            emailVerified: overview.user.emailVerified,
            newEmailController: _newEmailController,
            emailChangeBusy: _emailChangeBusy,
            emailChangeSucceeded: _emailChangeSucceeded,
            passwordResetBusy: _passwordResetBusy,
            passwordResetSucceeded: _passwordResetSucceeded,
            onRequestEmailChange: () => _requestEmailChange(
              needsReauth:
                  overview.capabilities.emailChange.needsReauthentication,
            ),
            onRequestPasswordReset: _requestPasswordReset,
          ),
        ),
      ),
    );
  }
}

class _SecurityBody extends StatelessWidget {
  const _SecurityBody({
    required this.capabilities,
    required this.currentEmail,
    required this.emailVerified,
    required this.newEmailController,
    required this.emailChangeBusy,
    required this.emailChangeSucceeded,
    required this.passwordResetBusy,
    required this.passwordResetSucceeded,
    required this.onRequestEmailChange,
    required this.onRequestPasswordReset,
  });

  final AccountCapabilities capabilities;
  final String currentEmail;
  final TextEditingController newEmailController;
  final bool emailVerified;
  final bool emailChangeBusy;
  final bool emailChangeSucceeded;
  final bool passwordResetBusy;
  final bool passwordResetSucceeded;
  final VoidCallback onRequestEmailChange;
  final VoidCallback onRequestPasswordReset;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final emailChange = capabilities.emailChange;
    final passwordAction = capabilities.passwordAction;

    return ListView(
      padding: EdgeInsets.all(tokens.spacing.md),
      children: [
        Text('E-posta', style: tokens.typography.titleMedium),
        SizedBox(height: tokens.spacing.xs),
        // Mevcut e-posta SALT OKUNUR + doğrulama durumu. Bu blok
        // `emailChange` yeteneğinden BAĞIMSIZDIR: e-posta değiştirme
        // kapalıyken de kullanıcının adresini ve doğrulanmış olup
        // olmadığını görmesi anlamlıdır (bkz. `AccountHomeScreen`'deki
        // aynı rozet kalıbı).
        // `container: true` + `ExcludeSemantics` OLMADAN bu etiket ekran
        // okuyucuya HİÇ ULAŞMAZ: `Semantics(label:)` tek başına yeni bir
        // düğüm oluşturmaz, çocukların (metin + ikon) kendi semantiği
        // geçerli olur ve ikonun `semanticLabel`ı olmadığı için doğrulama
        // durumu sessizce kaybolurdu. Bu ikisiyle e-posta ve rozet TEK bir
        // düğüm olarak, durumu da söyleyerek okunur.
        Semantics(
          container: true,
          label: emailVerified
              ? '$currentEmail, doğrulanmış'
              : '$currentEmail, doğrulanmamış',
          child: ExcludeSemantics(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    currentEmail,
                    style: tokens.typography.bodySmall.copyWith(
                      color: tokens.colors.muted,
                    ),
                  ),
                ),
                SizedBox(width: tokens.spacing.xs),
                Icon(
                  emailVerified ? Icons.verified_outlined : Icons.error_outline,
                  size: 16,
                  color: emailVerified
                      ? tokens.colors.mint
                      : tokens.colors.coral,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: tokens.spacing.sm),
        if (emailChange.isActionable) ...[
          TextField(
            controller: newEmailController,
            enabled: !emailChangeBusy,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Yeni e-posta adresi'),
          ),
          if (emailChange.needsReauthentication) ...[
            SizedBox(height: tokens.spacing.xs),
            Text(
              'Devam ettiğinde kimliğini doğrulaman için güvenli tarayıcı '
              'açılacak.',
              style: tokens.typography.bodySmall.copyWith(
                color: tokens.colors.muted,
              ),
            ),
          ],
          SizedBox(height: tokens.spacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: emailChangeBusy
                ? const CircularProgressIndicator()
                : FilledButton(
                    onPressed: onRequestEmailChange,
                    child: const Text('E-postayı değiştir'),
                  ),
          ),
          if (emailChangeSucceeded) ...[
            SizedBox(height: tokens.spacing.sm),
            const AccountCapabilityNotice(
              message:
                  'Doğrulama e-postası gönderildi. Gelen kutunu kontrol et.',
            ),
          ],
        ] else if (emailChange.isProviderManaged)
          const AccountCapabilityNotice(
            message:
                'E-posta adresin giriş sağlayıcın tarafından yönetiliyor. '
                'Değiştirmek için sağlayıcının hesap ayarlarını kullan.',
          ),
        SizedBox(height: tokens.spacing.lg),
        Divider(color: tokens.colors.line),
        SizedBox(height: tokens.spacing.lg),
        Text('Şifre', style: tokens.typography.titleMedium),
        SizedBox(height: tokens.spacing.xs),
        if (passwordAction.isActionable) ...[
          Text(
            'Yeni bir şifre belirlemen için sana bir e-posta göndeririz.',
            style: tokens.typography.bodySmall.copyWith(
              color: tokens.colors.muted,
            ),
          ),
          SizedBox(height: tokens.spacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: passwordResetBusy
                ? const CircularProgressIndicator()
                : FilledButton(
                    onPressed: onRequestPasswordReset,
                    child: const Text('Sıfırlama e-postası gönder'),
                  ),
          ),
          if (passwordResetSucceeded) ...[
            SizedBox(height: tokens.spacing.sm),
            const AccountCapabilityNotice(
              message: 'Şifre sıfırlama e-postası gönderildi.',
            ),
          ],
        ] else if (passwordAction.isProviderManaged)
          const AccountCapabilityNotice(
            message:
                'Şifren giriş sağlayıcın tarafından yönetiliyor. '
                'Değiştirmek için sağlayıcının hesap ayarlarını kullan.',
          ),
      ],
    );
  }
}
