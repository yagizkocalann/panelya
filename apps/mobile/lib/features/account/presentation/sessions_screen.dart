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

/// Sözleşmenin ISO-8601 `lastActiveAt` string'ini kullanıcıya gösterilecek
/// yerel metne çevirir. Sözleşme bunu bilerek STRING olarak tanımlar
/// (`DateTime` değil); ayrıştırılamayan bir değer UYDURULMAZ, olduğu gibi
/// gösterilir.
String formatSessionLastActive(String isoTimestamp) {
  final parsed = DateTime.tryParse(isoTimestamp);
  if (parsed == null) return isoTimestamp;
  final local = parsed.toLocal();
  const months = [
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
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${months[local.month - 1]} ${local.year}, $hour:$minute';
}

/// "Aktif oturumlar" ekranı (`/account/sessions`, bkz. ADR-047).
///
/// Her oturum sözleşmeden `current` (bu cihaz mı) ve `revocable`
/// (kapatılabilir mi) bayraklarını taşır; ekran bunları TAHMİN ETMEZ.
/// Tek oturum kapatma `DELETE /sessions/{id}` ile yapılır ve dönen
/// `currentSessionRevoked` SUNUCUDAN gelir — `true` ise uygulama yerel
/// oturumu da güvenli şekilde kapatır.
///
/// BİLİNEN SINIR (ADR-054, `docs/production-account-lifecycle.md`):
/// native refresh credential kimliği access token'dan hiçbir resmi/
/// desteklenen Auth0 mekanizmasıyla kesin eşlenemediği kod + Auth0
/// dokümantasyonu okunarak KANITLANMIŞTIR — bu geçici bir eksik değil,
/// mevcut mimarinin sağlayıcı sınırıdır. Bu yüzden `scope: others` toplu
/// kapatma sunucuda **503 fail-closed** döner. Bu ekran bunu TAKLİT
/// ETMEZ/başarılı göstermez — aksiyonu gösterir, sunucu 503 dönerse
/// hatayı dürüstçe iletir. Desteklenebilir tek çözüm yolu (gateway'in
/// kendi opak refresh-token broker'lığını üstlenmesi) ADR-039'un token
/// saklamama ilkesini değiştiren ayrı bir mimari karar gerektirir ve
/// henüz uygulanmamıştır.
class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  String? _pendingSessionId;
  bool _revokingOthers = false;

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Yerel oturumu kapatıp ana sayfaya döner. Sunucu
  /// `currentSessionRevoked: true` dediğinde çağrılır — istemci bunu
  /// kendisi tahmin etmez.
  ///
  /// Yerel temizlik başarısız olursa ana sayfaya GİTMEYİZ: kullanıcı hâlâ
  /// giriş yapmış durumdadır ve onu çıkmış gibi göstermek yanlış olurdu
  /// (ADR-010). Sebep dürüstçe bildirilir, kullanıcı tekrar deneyebilir.
  Future<void> _signOutLocally() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } on Object {
      _showError('Oturum kapatılamadı. Tekrar dene.');
      return;
    }
    if (mounted) context.go('/');
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
      final result = await ref
          .read(accountRepositoryProvider)
          .revokeSession(session.id);
      ref.invalidate(accountSessionsProvider);
      if (result.currentSessionRevoked) {
        await _signOutLocally();
        return;
      }
    } on AccountRepositoryException catch (error) {
      _showError(error.message);
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
      final result = await ref
          .read(accountRepositoryProvider)
          .revokeSessions(scope: 'others');
      ref.invalidate(accountSessionsProvider);
      if (result.currentSessionRevoked) {
        await _signOutLocally();
        return;
      }
    } on AccountRepositoryException catch (error) {
      // `scope: others` mobilde şu an 503 fail-closed dönüyor (bkz. sınıf
      // dokümantasyonu). Hata OLDUĞU GİBİ gösterilir; sahte bir başarı
      // veya sessiz yutma YOKTUR.
      _showError(error.message);
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
            message: accountErrorMessage(error),
            onRetry: () => ref.invalidate(accountSessionsProvider),
          ),
          data: (response) => response.sessions.isEmpty
              ? const AppEmptyView(message: 'Aktif oturum bulunamadı.')
              : _SessionsList(
                  sessions: response.sessions,
                  pendingSessionId: _pendingSessionId,
                  revokingOthers: _revokingOthers,
                  onRevoke: _confirmRevokeSession,
                  onRevokeOthers: () => _confirmRevokeOthers(
                    response.sessions.where((s) => !s.current).length,
                  ),
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
    final otherRevocableCount = sessions
        .where((s) => !s.current && s.revocable)
        .length;

    return Column(
      children: [
        // ADR-010: kapatılabilecek başka bir oturum yoksa bu aksiyon HİÇ
        // render edilmez.
        if (otherRevocableCount > 0)
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
          Icon(
            accountSessionPlatformIcon(session.platform),
            color: tokens.colors.ink,
          ),
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
                    if (session.current) ...[
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
                  formatSessionLastActive(session.lastActiveAt),
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
          // ADR-010: sözleşme bu oturumun kapatılamayacağını söylüyorsa
          // (`revocable: false`) buton HİÇ gösterilmez — devre dışı bir
          // buton da gösterilmez.
          else if (session.revocable)
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
