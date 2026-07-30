import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../shared/widgets/home_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../core/contracts/generated/generated.dart';
import '../domain/account_exceptions.dart';
import 'account_error_message.dart';
import 'account_providers.dart';

/// "Engellenen hesaplar" ekranı (`/account/blocked`, bkz. ADR-047): listeler
/// ve tek tek engel kaldırma sağlar. Engeli kaldırma geri alınabilir/az
/// riskli bir aksiyon olduğu için (kullanıcı istediğinde tekrar
/// engelleyebilir) — `sessions_screen.dart`/`downloads_screen.dart`daki
/// KALICI/YIKICI aksiyonların aksine — bilerek bir onay diyaloğu YOKTUR;
/// başarısızlık yalnız bir SnackBar ile bildirilir, satır olduğu gibi
/// kalır.
class BlockedAccountsScreen extends ConsumerStatefulWidget {
  const BlockedAccountsScreen({super.key});

  @override
  ConsumerState<BlockedAccountsScreen> createState() =>
      _BlockedAccountsScreenState();
}

class _BlockedAccountsScreenState extends ConsumerState<BlockedAccountsScreen> {
  String? _pendingAccountId;

  Future<void> _unblock(BlockedAccount account) async {
    setState(() => _pendingAccountId = account.id);
    try {
      await ref.read(accountRepositoryProvider).unblockAccount(account.id);
      ref.invalidate(blockedAccountsProvider);
    } on AccountRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _pendingAccountId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final blocked = ref.watch(blockedAccountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Engellenen hesaplar'),
        actions: const [HomeButton()],
      ),
      body: SafeArea(
        child: blocked.when(
          loading: () =>
              const AppLoadingView(label: 'Engellenen hesaplar yükleniyor'),
          error: (error, stackTrace) => AppErrorView(
            message: accountErrorMessage(error),
            onRetry: () => ref.invalidate(blockedAccountsProvider),
          ),
          data: (response) => response.accounts.isEmpty
              ? const AppEmptyView(message: 'Engellediğin hesap yok.')
              : ListView.separated(
                  padding: EdgeInsets.all(tokens.spacing.md),
                  itemCount: response.accounts.length,
                  separatorBuilder: (context, index) =>
                      SizedBox(height: tokens.spacing.sm),
                  itemBuilder: (context, index) {
                    final account = response.accounts[index];
                    return _BlockedAccountTile(
                      account: account,
                      busy: _pendingAccountId == account.id,
                      onUnblock: () => _unblock(account),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _BlockedAccountTile extends StatelessWidget {
  const _BlockedAccountTile({
    required this.account,
    required this.busy,
    required this.onUnblock,
  });

  final BlockedAccount account;
  final bool busy;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: EdgeInsets.all(tokens.spacing.md),
      decoration: BoxDecoration(
        color: tokens.colors.surface2,
        borderRadius: BorderRadius.circular(tokens.radii.md),
        border: Border.all(color: tokens.colors.line),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: tokens.colors.surface3,
            backgroundImage: account.avatarUrl != null
                ? NetworkImage(account.avatarUrl!)
                : null,
            child: account.avatarUrl == null
                ? Text(_blockedAccountInitial(account.displayName))
                : null,
          ),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Text(
              account.displayName,
              style: tokens.typography.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: tokens.spacing.sm),
          if (busy)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: onUnblock,
              child: const Text('Engeli kaldır'),
            ),
        ],
      ),
    );
  }
}

String _blockedAccountInitial(String displayName) {
  final trimmed = displayName.trim();
  return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
}
