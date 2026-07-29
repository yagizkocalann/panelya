import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../shared/widgets/home_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/account_exceptions.dart';
import '../domain/account_provider.dart';
import 'account_providers.dart';

/// "E-posta ve şifre" ekranı (`/account/security`, bkz. ADR-047).
///
/// [AccountProvider.database] hesaplarında e-posta değiştirme ve şifre
/// sıfırlama e-postası gönderme aksiyonlarını gösterir. Diğer sağlayıcılarda
/// (ör. Google) şifre/e-posta sağlayıcı tarafından yönetildiği için bu
/// ekran YALNIZ açıklayıcı, etkileşimsiz bir metin gösterir — ÇALIŞMAYAN
/// bir form/buton GÖSTERMEZ (ADR-010). Uygulama içinde eski/yeni şifre
/// alanı HİÇBİR ZAMAN oluşturulmaz — bkz. görev talimatı; taze kimlik
/// doğrulaması gerektiğinde mevcut sistem tarayıcılı Auth0 akışı (bkz.
/// `features/auth/`) kullanılır.
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

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is AccountRepositoryException
        ? error.message
        : 'Beklenmeyen bir hata oluştu.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _requestEmailChange() async {
    setState(() {
      _emailChangeBusy = true;
      _emailChangeSucceeded = false;
    });
    try {
      await ref
          .read(accountRepositoryProvider)
          .requestEmailChange(newEmail: _newEmailController.text.trim());
      if (mounted) setState(() => _emailChangeSucceeded = true);
    } on AccountRepositoryException catch (error) {
      _showError(error);
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
      _showError(error);
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
            message: 'Beklenmeyen bir hata oluştu.',
            onRetry: () => ref.invalidate(accountOverviewProvider),
          ),
          data: (overview) => switch (overview.provider) {
            AccountProvider.database => _DatabaseSecurityBody(
              newEmailController: _newEmailController,
              emailChangeBusy: _emailChangeBusy,
              emailChangeSucceeded: _emailChangeSucceeded,
              passwordResetBusy: _passwordResetBusy,
              passwordResetSucceeded: _passwordResetSucceeded,
              onRequestEmailChange: _requestEmailChange,
              onRequestPasswordReset: _requestPasswordReset,
            ),
            AccountProvider.google => const _SocialProviderBody(),
          },
        ),
      ),
    );
  }
}

class _DatabaseSecurityBody extends StatelessWidget {
  const _DatabaseSecurityBody({
    required this.newEmailController,
    required this.emailChangeBusy,
    required this.emailChangeSucceeded,
    required this.passwordResetBusy,
    required this.passwordResetSucceeded,
    required this.onRequestEmailChange,
    required this.onRequestPasswordReset,
  });

  final TextEditingController newEmailController;
  final bool emailChangeBusy;
  final bool emailChangeSucceeded;
  final bool passwordResetBusy;
  final bool passwordResetSucceeded;
  final VoidCallback onRequestEmailChange;
  final VoidCallback onRequestPasswordReset;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return ListView(
      padding: EdgeInsets.all(tokens.spacing.md),
      children: [
        Text('E-posta değiştir', style: tokens.typography.titleMedium),
        SizedBox(height: tokens.spacing.sm),
        TextField(
          controller: newEmailController,
          enabled: !emailChangeBusy,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Yeni e-posta adresi'),
        ),
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
          _ConfirmationPanel(
            message: 'Doğrulama e-postası gönderildi. Gelen kutunu kontrol et.',
          ),
        ],
        SizedBox(height: tokens.spacing.lg),
        Divider(color: tokens.colors.line),
        SizedBox(height: tokens.spacing.lg),
        Text(
          'Şifre sıfırlama e-postası gönder',
          style: tokens.typography.titleMedium,
        ),
        SizedBox(height: tokens.spacing.xs),
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
          _ConfirmationPanel(
            message: 'Şifre sıfırlama e-postası gönderildi.',
          ),
        ],
      ],
    );
  }
}

class _ConfirmationPanel extends StatelessWidget {
  const _ConfirmationPanel({required this.message});

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
        children: [
          Icon(Icons.check_circle_outline, color: tokens.colors.mint),
          SizedBox(width: tokens.spacing.sm),
          Expanded(
            child: Text(message, style: tokens.typography.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _SocialProviderBody extends StatelessWidget {
  const _SocialProviderBody();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Text(
          'Google hesabınla giriş yaptığın için şifren ve e-postan Google '
          'tarafından yönetiliyor. Bunları değiştirmek için Google '
          'hesap ayarlarını kullan.',
          textAlign: TextAlign.center,
          style: tokens.typography.bodyMedium,
        ),
      ),
    );
  }
}
