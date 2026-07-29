import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../shared/widgets/home_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/domain/auth_exceptions.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/account_deletion_summary.dart';
import '../domain/account_exceptions.dart';
import 'account_providers.dart';

/// "Hesabı sil" ekranı (`/account/delete`, bkz. ADR-047): en yıkıcı/geri
/// alınamaz aksiyon olduğu için bu uygulamadaki DİĞER tüm onay
/// diyaloglarından (bkz. `downloads_screen.dart`, `sessions_screen.dart` —
/// hepsi TEK adımlı) FARKLI olarak İKİ AYRI, artan şiddette onay diyaloğu
/// ister; ikisi de aynı `showDialog<bool>` + `AlertDialog` + `TextButton`
/// (`Vazgeç`/yıkıcı fiil) kalıbını kullanır, yalnız zincirlenmiştir.
///
/// TAZE KİMLİK DOĞRULAMASI — MEVCUT ORKESTRASYON GEÇİCİDİR, DEĞİŞECEK:
///
/// Bu ekran bugün `authRepositoryProvider.beginSignIn()` +
/// `authBrowserProvider.authenticate()`yi çağırıp dönen callback'in
/// `code`'unu `AccountRepository.deleteAccount`a geçirir. Bu YALNIZ
/// presentation-only demo içindir — web tarafı bu zinciri açıkça REDDETTİ
/// (Auth0 authorization code'u gerçek hesap mutation'ına doğrudan
/// verilmeyecek). Gerçek akış (`/api/account/reauthentication/start` ->
/// `max_age=0` + PKCE -> `.../complete` -> tek kullanımlık, amaca bağlı
/// `reauthenticationToken`) için bkz. `AccountRepository`nin sınıf
/// dokümantasyonundaki ayrıntılı not; sözleşme `main`e girdiğinde bu
/// metodun (`_startDeletion`) gövdesi ona göre değişecek.
///
/// Değişmeyecek olan: `completeSignIn` ÇAĞRILMAZ — bu canlı oturumu
/// MUTASYONA UĞRATIR; gerçek sözleşme de mevcut `AuthRepository` oturumunu
/// ve `TokenStore`u değiştirmemeyi garanti ediyor.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _busy = false;

  Future<bool> _confirmStep1() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hesabını silmek istediğine emin misin?'),
        content: const Text(
          'Hesabını sildikten sonra aynı bilgilerle tekrar giriş yaparak '
          'geri dönemezsin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Devam et'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<bool> _confirmStep2() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bu işlem geri alınamaz'),
        content: const Text(
          'Hesabın, Auth0 kimliğin ve tüm aktif oturumların kalıcı olarak '
          'silinecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Evet, hesabımı kalıcı olarak sil'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _startDeletion() async {
    if (!await _confirmStep1()) return;
    if (!mounted) return;
    if (!await _confirmStep2()) return;
    if (!mounted) return;

    setState(() => _busy = true);
    try {
      final authRepository = ref.read(authRepositoryProvider);
      final request = await authRepository.beginSignIn();
      final browser = ref.read(authBrowserProvider);
      final callbackUri = await browser.authenticate(
        authorizationUrl: request.authorizationUrl,
        callbackUrlScheme: request.callbackUrlScheme,
      );
      if (callbackUri == null) {
        // Kullanıcı taze kimlik doğrulamasını iptal etti — sessizce çık
        // (bkz. `AuthUserCancelledException` ile aynı desen, ama burada
        // `completeSignIn` hiç çağrılmadığı için o istisna tipi
        // kullanılmaz).
        return;
      }
      final reauthCredential = callbackUri.queryParameters['code'];
      if (reauthCredential == null || reauthCredential.isEmpty) {
        throw const AuthCallbackException(
          'callback code parametresi eksik.',
        );
      }
      await ref
          .read(accountRepositoryProvider)
          .deleteAccount(reauthCredential: reauthCredential);
      await authRepository.logout();
      if (mounted) context.go('/');
    } on AccountRepositoryException catch (error) {
      _showError(error.message);
    } on AuthRepositoryException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(accountDeletionSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hesabı sil'),
        actions: const [HomeButton()],
      ),
      body: SafeArea(
        child: summary.when(
          loading: () => const AppLoadingView(label: 'Yükleniyor'),
          error: (error, stackTrace) => AppErrorView(
            message: 'Beklenmeyen bir hata oluştu.',
            onRetry: () => ref.invalidate(accountDeletionSummaryProvider),
          ),
          data: (summary) => _DeleteAccountBody(
            summary: summary,
            busy: _busy,
            onDelete: _startDeletion,
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountBody extends StatelessWidget {
  const _DeleteAccountBody({
    required this.summary,
    required this.busy,
    required this.onDelete,
  });

  final AccountDeletionSummary summary;
  final bool busy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return ListView(
      padding: EdgeInsets.all(tokens.spacing.md),
      children: [
        Text('Silinecekler', style: tokens.typography.titleMedium),
        SizedBox(height: tokens.spacing.sm),
        for (final item in summary.deletedItems) _BulletItem(text: item),
        SizedBox(height: tokens.spacing.lg),
        Text('Anonimleştirilecekler', style: tokens.typography.titleMedium),
        SizedBox(height: tokens.spacing.sm),
        for (final item in summary.anonymizedItems) _BulletItem(text: item),
        SizedBox(height: tokens.spacing.xl),
        Center(
          child: busy
              ? const CircularProgressIndicator()
              : FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.colors.coral,
                  ),
                  onPressed: onDelete,
                  child: const Text('Hesabımı sil'),
                ),
        ),
      ],
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: tokens.typography.bodyMedium),
          Expanded(
            child: Text(text, style: tokens.typography.bodyMedium),
          ),
        ],
      ),
    );
  }
}
