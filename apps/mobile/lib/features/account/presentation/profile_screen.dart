import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../shared/widgets/home_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../core/contracts/generated/generated.dart';
import '../domain/account_exceptions.dart';
import 'account_avatar.dart';
import 'account_capability_view.dart';
import 'account_error_message.dart';
import 'account_providers.dart';

/// "Profil" ekranı (`/account/profile`, bkz. ADR-047): görünen adı
/// düzenleme; avatar düzenleme henüz DESTEKLENMİYOR (bkz.
/// `AccountAvatar` — bu ekran onu yalnız GÖSTERİR, tıklanabilir bir
/// kamera ikonu/buton EKLEMEZ, ADR-010). E-posta burada serbest metin
/// olarak DEĞİŞTİRİLMEZ — "E-posta ve şifre" ekranına yönlendirir (bkz.
/// `security_screen.dart`).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _displayNameController = TextEditingController();
  bool _prefilled = false;
  bool _saving = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(accountRepositoryProvider)
          .updateProfile(displayName: _displayNameController.text.trim());
      // Sözleşme `PATCH /api/account/profile`den TAZELENMİŞ özeti döner;
      // provider'ı geçersiz kılmak diğer ekranların (ör. Hesabım ana
      // ekranı) da sunucunun gerçeğini görmesini sağlar.
      ref.invalidate(accountOverviewProvider);
    } on AccountRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(accountOverviewProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: const [HomeButton()],
      ),
      body: SafeArea(
        child: overview.when(
          loading: () => const AppLoadingView(label: 'Profil yükleniyor'),
          error: (error, stackTrace) => AppErrorView(
            message: accountErrorMessage(error),
            onRetry: () => ref.invalidate(accountOverviewProvider),
          ),
          data: (overview) {
            // Yalnız bir kez, veri ilk geldiğinde denetleyiciyi doldurur
            // (kullanıcının o andan sonraki düzenlemelerinin üzerine
            // ASLA yazmaz — `accountOverviewProvider` yeniden
            // tetiklenirse bile).
            if (!_prefilled) {
              _displayNameController.text = overview.user.displayName;
              _prefilled = true;
            }
            return _ProfileBody(
              overview: overview,
              displayNameController: _displayNameController,
              saving: _saving,
              onSave: _save,
            );
          },
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.overview,
    required this.displayNameController,
    required this.saving,
    required this.onSave,
  });

  final AccountOverviewResponse overview;
  final TextEditingController displayNameController;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return ListView(
      padding: EdgeInsets.all(tokens.spacing.md),
      children: [
        Center(
          child: Column(
            children: [
              AccountAvatar(user: overview.user),
              SizedBox(height: tokens.spacing.sm),
              // Avatar düzenleme durumu SÖZLEŞMEDEN gelir (capability);
              // hiçbir durumda tıklanabilir bir kamera ikonu/devre dışı
              // buton gösterilmez (ADR-010).
              Text(
                overview.capabilities.avatarEditing.isProviderManaged
                    ? 'Profil fotoğrafın giriş sağlayıcın tarafından '
                          'yönetiliyor.'
                    : 'Profil fotoğrafı düzenleme bu sürümde desteklenmiyor.',
                textAlign: TextAlign.center,
                style: tokens.typography.bodySmall.copyWith(
                  color: tokens.colors.muted,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.lg),
        Text('Görünen ad', style: tokens.typography.label),
        SizedBox(height: tokens.spacing.xs),
        TextField(
          controller: displayNameController,
          enabled: !saving,
          textInputAction: TextInputAction.done,
        ),
        SizedBox(height: tokens.spacing.md),
        Align(
          alignment: Alignment.centerRight,
          child: saving
              ? const CircularProgressIndicator()
              : FilledButton(
                  onPressed: onSave,
                  child: const Text('Kaydet'),
                ),
        ),
        SizedBox(height: tokens.spacing.lg),
        Divider(color: tokens.colors.line),
        SizedBox(height: tokens.spacing.md),
        Semantics(
          button: true,
          label: 'E-postanı değiştirmek için E-posta ve şifre ekranına git',
          child: InkWell(
            onTap: () => context.push('/account/security'),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: tokens.sizes.minTouchTarget,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('E-posta', style: tokens.typography.label),
                        Text(
                          overview.user.email,
                          style: tokens.typography.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: tokens.colors.muted),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: tokens.spacing.xs),
        Text(
          'E-postanı değiştirmek için "E-posta ve şifre" ekranına git.',
          style: tokens.typography.bodySmall.copyWith(
            color: tokens.colors.muted,
          ),
        ),
      ],
    );
  }
}
