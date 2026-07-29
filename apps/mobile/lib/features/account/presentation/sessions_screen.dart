import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../shared/widgets/home_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/account_exceptions.dart';
import '../domain/account_session.dart';
import 'account_providers.dart';

const _turkishMonthAbbreviations = [
  'Oca',
  'Şub',
  'Mar',
  'Nis',
  'May',
  'Haz',
  'Tem',
  'Ağu',
  'Eyl',
  'Eki',
  'Kas',
  'Ara',
];

String _formatLastActive(DateTime dateTime) {
  final month = _turkishMonthAbbreviations[dateTime.month - 1];
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '${dateTime.day} $month ${dateTime.year}, $hour:$minute';
}

/// "Aktif oturumlar" ekranı (`/account/sessions`, bkz. ADR-047): web/
/// Android/iOS oturumlarını listeler, mevcut cihazı "Bu cihaz" rozetiyle
/// vurgular, tek tek veya toplu (mevcut cihaz HARİÇ) kapatma sağlar.
///
/// Mevcut cihazın KENDİ oturumu kapatılırsa (bkz. [AccountSession.isCurrentDevice])
/// uygulama yerel olarak da güvenli şekilde çıkış durumuna alınır (bkz.
/// `_confirmRevokeSession` — `authRepositoryProvider.logout()` çağrısı);
/// `AccountRepository.revokeSession` bunu KENDİSİ yapmaz (bkz. o
/// metodun dokümantasyonu).
class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  String? _pendingSessionId;
  bool _revokingOthers = false;

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is AccountRepositoryException
        ? error.message
        : 'Beklenmeyen bir hata oluştu.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmRevokeSession(AccountSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Oturumu kapat'),
        content: Text('"${session.deviceLabel}" oturumu kapatılsın mı?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Oturumu kapat'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _pendingSessionId = session.id);
    try {
      await ref.read(accountRepositoryProvider).revokeSession(session.id);
      ref.invalidate(accountSessionsProvider);
      if (session.isCurrentDevice) {
        await ref.read(authRepositoryProvider).logout();
        if (mounted) context.go('/');
        return;
      }
    } on AccountRepositoryException catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _pendingSessionId = null);
    }
  }

  Future<void> _confirmRevokeOthers(int otherSessionCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Diğer tüm oturumları kapat'),
        content: Text(
          'Bu cihaz hariç $otherSessionCount oturum kapatılsın mı?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _revokingOthers = true);
    try {
      await ref.read(accountRepositoryProvider).revokeOtherSessions();
      ref.invalidate(accountSessionsProvider);
    } on AccountRepositoryException catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _revokingOthers = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(accountSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aktif oturumlar'),
        actions: const [HomeButton()],
      ),
      body: SafeArea(
        child: sessions.when(
          loading: () => const AppLoadingView(label: 'Oturumlar yükleniyor'),
          error: (error, stackTrace) => AppErrorView(
            message: 'Beklenmeyen bir hata oluştu.',
            onRetry: () => ref.invalidate(accountSessionsProvider),
          ),
          data: (sessionList) => sessionList.isEmpty
              ? const AppEmptyView(message: 'Aktif oturum bulunamadı.')
              : _SessionsList(
                  sessions: sessionList,
                  pendingSessionId: _pendingSessionId,
                  revokingOthers: _revokingOthers,
                  onRevoke: _confirmRevokeSession,
                  onRevokeOthers: () =>
                      _confirmRevokeOthers(sessionList.length - 1),
                ),
        ),
      ),
    );
  }
}

class _SessionsList extends StatelessWidget {
  const _SessionsList({
    required this.sessions,
    required this.pendingSessionId,
    required this.revokingOthers,
    required this.onRevoke,
    required this.onRevokeOthers,
  });

  final List<AccountSession> sessions;
  final String? pendingSessionId;
  final bool revokingOthers;
  final void Function(AccountSession) onRevoke;
  final VoidCallback onRevokeOthers;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      children: [
        // ADR-010: mevcut cihazdan başka kapatılacak oturum yoksa bu
        // aksiyon HİÇ render edilmez.
        if (sessions.length > 1)
          Padding(
            padding: EdgeInsets.all(tokens.spacing.md),
            child: Align(
              alignment: Alignment.centerRight,
              child: revokingOthers
                  ? const CircularProgressIndicator()
                  : OutlinedButton(
                      onPressed: onRevokeOthers,
                      child: const Text('Diğer tüm oturumları kapat'),
                    ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.all(tokens.spacing.md),
            itemCount: sessions.length,
            separatorBuilder: (context, index) =>
                SizedBox(height: tokens.spacing.sm),
            itemBuilder: (context, index) {
              final session = sessions[index];
              return _SessionTile(
                session: session,
                busy: pendingSessionId == session.id,
                onRevoke: () => onRevoke(session),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.busy,
    required this.onRevoke,
  });

  final AccountSession session;
  final bool busy;
  final VoidCallback onRevoke;

  IconData _platformIcon(AccountSessionPlatform platform) => switch (platform) {
    AccountSessionPlatform.web => Icons.language,
    AccountSessionPlatform.android => Icons.phone_android,
    AccountSessionPlatform.ios => Icons.phone_iphone,
  };

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
          Icon(_platformIcon(session.platform), color: tokens.colors.ink),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        session.deviceLabel,
                        style: tokens.typography.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (session.isCurrentDevice) ...[
                      SizedBox(width: tokens.spacing.xs),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: tokens.spacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.colors.mint.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(
                            tokens.radii.pill,
                          ),
                        ),
                        child: Text(
                          'Bu cihaz',
                          style: tokens.typography.label.copyWith(
                            color: tokens.colors.mint,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  _formatLastActive(session.lastActiveAt),
                  style: tokens.typography.bodySmall.copyWith(
                    color: tokens.colors.muted,
                  ),
                ),
              ],
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
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Oturumu kapat',
              onPressed: onRevoke,
            ),
        ],
      ),
    );
  }
}
