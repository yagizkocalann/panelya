import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../../shared/widgets/home_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/account_exceptions.dart';
import 'account_capability_view.dart';
import 'account_error_message.dart';
import 'account_providers.dart';

/// "Hesabı sil" ekranı (`/account/delete`, bkz. ADR-047).
///
/// Bu uygulamadaki en yıkıcı/geri alınamaz aksiyon olduğu için diğer TÜM
/// onay diyaloglarından (hepsi TEK adımlı) farklı olarak İKİ AYRI, artan
/// şiddette onay ister; ikisi de aynı `showDialog<bool>` + `AlertDialog` +
/// `TextButton` (`Vazgeç`/yıkıcı fiil) kalıbını kullanır, yalnız
/// zincirlenmiştir.
///
/// TAZE KİMLİK DOĞRULAMASI: silme öncesi `AccountReauthenticator` ile
/// sunucudan AMACA BAĞLI, tek kullanımlık bir `reauthenticationToken`
/// alınır (`start` -> sistem tarayıcısı -> `complete`). Authorization code
/// mutation'a ASLA doğrudan verilmez ve mevcut `AuthRepository` oturumu /
/// `TokenStore` DEĞİŞTİRİLMEZ.
///
/// Silme ASENKRON olabilir: sözleşme `status: pending | completed` döner.
/// `pending` durumunda kullanıcı yerel olarak çıkışa alınır ama işlemin
/// sunucuda sürdüğü dürüstçe bildirilir — "tamamlandı" DENMEZ.
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
          'Kimliğini doğruladıktan sonra hesabın kalıcı olarak silinecek.',
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
      // 1-3: start -> sistem tarayıcısı -> complete; sonuç amaca bağlı,
      // tek kullanımlık bir token.
      final token = await ref
          .read(accountReauthenticatorProvider)
          .obtainToken(AccountReauthenticationPurpose.account_deletion);

      // 4: token YALNIZ bu mutation'da kullanılır. `Idempotency-Key`
      // adapter tarafından üretilip gönderilir (bkz.
      // `HttpAccountRepository.deleteAccount`).
      final operation = await ref
          .read(accountRepositoryProvider)
          .deleteAccount(reauthenticationToken: token);

      // Sunucu tarafında hesap silindi/silinmek üzere; yerel oturumu da
      // temizle.
      await ref.read(authRepositoryProvider).logout();
      if (!mounted) return;

      if (operation.status == 'pending') {
        // ASENKRON silme: "tamamlandı" demeyiz.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Silme işlemi başlatıldı ve kısa süre içinde tamamlanacak.',
            ),
          ),
        );
      }
      context.go('/');
    } on AccountReauthenticationCancelledException {
      // Kullanıcı taze kimlik doğrulamasını iptal etti — hata gösterilmez,
      // silme yapılmaz.
    } on AccountRepositoryException catch (error) {
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
            message: accountErrorMessage(error),
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

  final AccountDeletionSummaryResponse summary;
  final bool busy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return ListView(
      padding: EdgeInsets.all(tokens.spacing.md),
      children: [
        if (summary.deleted.isNotEmpty) ...[
          Text('Silinecekler', style: tokens.typography.titleMedium),
          SizedBox(height: tokens.spacing.sm),
          for (final effect in summary.deleted)
            _BulletItem(text: accountDeletionEffectLabel(effect)),
          SizedBox(height: tokens.spacing.lg),
        ],
        if (summary.anonymized.isNotEmpty) ...[
          Text('Anonimleştirilecekler', style: tokens.typography.titleMedium),
          SizedBox(height: tokens.spacing.sm),
          for (final effect in summary.anonymized)
            _BulletItem(text: accountDeletionEffectLabel(effect)),
          SizedBox(height: tokens.spacing.lg),
        ],
        // `retained`: silinmeyen/anonimleşmeyen, yasal olarak SAKLANAN
        // kayıtlar. Kullanıcı eksik bilgiyle onay vermesin diye dürüstçe
        // gösterilir (sözleşme bunu ayrı bir liste olarak tanımlar).
        if (summary.retained.isNotEmpty) ...[
          Text('Saklanacaklar', style: tokens.typography.titleMedium),
          SizedBox(height: tokens.spacing.xs),
          Text(
            'Aşağıdaki kayıtlar yasal yükümlülükler nedeniyle silinmez.',
            style: tokens.typography.bodySmall.copyWith(
              color: tokens.colors.muted,
            ),
          ),
          SizedBox(height: tokens.spacing.sm),
          for (final effect in summary.retained)
            _BulletItem(text: accountDeletionEffectLabel(effect)),
          SizedBox(height: tokens.spacing.lg),
        ],
        SizedBox(height: tokens.spacing.md),
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
