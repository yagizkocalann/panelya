import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../../shared/widgets/home_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/auth_exceptions.dart';
import '../domain/auth_session_state.dart';
import 'auth_providers.dart';

/// Hesap ekranı (bkz. docs/mobile-handoff.md "Hesap ve kütüphane
/// entegrasyonu" — ADR-039 ortak auth sözleşmesi hazır, ama gerçek Auth0
/// tenant/gateway/JWKS değerleri henüz sağlanmadı; web tarafı bu yüzden
/// `/api/auth/config`'i bilerek "fail closed" 503 döndürüyor, bkz.
/// `HttpAuthRepository` doc yorumu).
///
/// Bu ekran bilerek O GERÇEK isteği yapar — sahte/mock bir "başarılı
/// giriş" GÖSTERMEZ; tenant kurulana kadar dürüstçe "servis şu an
/// kullanılamıyor" hatasını [AppErrorView] ile gösterir. Bu, ADR-010
/// ihlali DEĞİLDİR: çalışmayan/hiçbir şey yapmayan bir buton değil,
/// gerçek bir isteğin doğru raporlanan başarısızlık durumudur (aynı
/// desen: `discover_screen.dart`daki API hataları).
///
/// Yalnız `AuthFeatureConfig.enabled` (`AUTH_ENABLED` dart-define) açıkken
/// erişilebilir — bkz. `discover_screen.dart`daki giriş noktası, o
/// koşullu render olmadan bu ekrana ULAŞILAMAZ (`/account`
/// `resolveCustomSchemeRoute`'un tanıdığı rotalardan biri değil, `/downloads`
/// ile aynı gerekçeyle mobile-only). Bu yüzden ekranın kendisi bayrağı
/// AYRICA kontrol etmez — YAGNI, bkz. AGENTS.md.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _busy = false;
  String? _errorMessage;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final repository = ref.read(authRepositoryProvider);
      final request = await repository.beginSignIn();
      // Gerçek Auth0 tenant'ı sağlandığında burada sistem tarayıcısı
      // açılıp dönen URI `completeSignIn`e verilecek (bkz. `AuthBrowser`);
      // bugün `beginSignIn` yukarıdaki 503'te durduğu için bu satıra hiç
      // ulaşılmaz.
      final browser = ref.read(authBrowserProvider);
      final callbackUri = await browser.authenticate(
        authorizationUrl: request.authorizationUrl,
        callbackUrlScheme: request.callbackUrlScheme,
      );
      if (callbackUri == null) {
        throw const AuthUserCancelledException();
      }
      await repository.completeSignIn(callbackUri);
    } on AuthUserCancelledException {
      // Kullanıcı iptal etti — ayrı bir hata mesajı gösterilmez.
    } on AuthRepositoryException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    await ref.read(authRepositoryProvider).logout();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hesabım'),
        actions: const [HomeButton()],
      ),
      body: SafeArea(
        child: switch (session) {
          AuthAnonymous() => _AnonymousView(
            busy: _busy,
            errorMessage: _errorMessage,
            onSignIn: _signIn,
          ),
          AuthAuthenticated(:final user) => _AuthenticatedView(
            user: user,
            busy: _busy,
            onSignOut: _signOut,
          ),
        },
      ),
    );
  }
}

class _AnonymousView extends StatelessWidget {
  const _AnonymousView({
    required this.busy,
    required this.errorMessage,
    required this.onSignIn,
  });

  final bool busy;
  final String? errorMessage;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return AppErrorView(
        message: errorMessage!,
        onRetry: busy ? null : onSignIn,
      );
    }

    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Hesabına giriş yaparak kütüphaneni ve favorilerini senkronize et.',
              textAlign: TextAlign.center,
              style: tokens.typography.bodyMedium,
            ),
            SizedBox(height: tokens.spacing.lg),
            if (busy)
              const CircularProgressIndicator()
            else
              FilledButton(onPressed: onSignIn, child: const Text('Giriş yap')),
          ],
        ),
      ),
    );
  }
}

class _AuthenticatedView extends StatelessWidget {
  const _AuthenticatedView({
    required this.user,
    required this.busy,
    required this.onSignOut,
  });

  final AuthUser user;
  final bool busy;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(user.displayName, style: tokens.typography.titleMedium),
            SizedBox(height: tokens.spacing.xs),
            Text(
              user.email,
              style: tokens.typography.bodySmall.copyWith(
                color: tokens.colors.muted,
              ),
            ),
            SizedBox(height: tokens.spacing.lg),
            if (busy)
              const CircularProgressIndicator()
            else
              OutlinedButton(
                onPressed: onSignOut,
                child: const Text('Çıkış yap'),
              ),
          ],
        ),
      ),
    );
  }
}
