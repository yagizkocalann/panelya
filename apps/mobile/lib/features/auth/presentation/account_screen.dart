import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../shared/widgets/home_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../../account/presentation/account_home_screen.dart';
import '../../legal/presentation/legal_links.dart';
import '../domain/auth_exceptions.dart';
import '../domain/auth_session_state.dart';
import 'auth_providers.dart';

/// Hesap ekranı (bkz. docs/mobile-handoff.md "Hesap ve kütüphane
/// entegrasyonu", ADR-039, ADR-047). Gerçek Auth0 dev tenant'ı canlıda
/// doğrulandı (PR #36, `main@b8e39da`); bu ekran sistem tarayıcısında
/// gerçek bir Authorization Code + PKCE oturumu açar (bkz.
/// `HttpAuthRepository`, `SystemAuthBrowser`).
///
/// Bu ekran bilerek O GERÇEK isteği yapar — sahte/mock bir "başarılı
/// giriş" GÖSTERMEZ; sağlayıcı/gateway hatası olursa dürüstçe hatayı
/// [AppErrorView] ile gösterir. Bu, ADR-010 ihlali DEĞİLDİR:
/// çalışmayan/hiçbir şey yapmayan bir buton değil, gerçek bir isteğin
/// doğru raporlanan başarısızlık durumudur (aynı desen:
/// `discover_screen.dart`daki API hataları).
///
/// Kimliği doğrulanmışken bu ekran yalnız Scaffold/AppBar/anonim kapıyı
/// taşır — "Hesabım ana ekranı"nın gerçek içeriği (ADR-047: avatar/görünen
/// ad, e-posta/sağlayıcı, Profil/E-posta ve şifre/Aktif oturumlar/
/// Engellenen hesaplar/Hesabı sil/Çıkış yap) `features/account/`
/// modülündeki `AccountHomeScreen`'e devredilir (bkz. o dosyanın
/// dokümantasyonu).
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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hesabım'),
        actions: const [HomeButton()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (session) {
                AuthAnonymous() => _AnonymousView(
                  busy: _busy,
                  errorMessage: _errorMessage,
                  onSignIn: _signIn,
                ),
                // Kimliği doğrulanmışken bu ekranın gösterdiği içerik (bkz.
                // ADR-047 "Hesabım ana ekranı") `features/account/` modülüne
                // devredilir — bu ekran yalnız Scaffold/AppBar/anonim kapıyı
                // taşır.
                AuthAuthenticated() => const AccountHomeScreen(),
              },
            ),
            // Giriş durumundan BAĞIMSIZ olarak her zaman görünür: yasal
            // bilgiye ulaşmak hesap gerektirmez (bkz. [LegalLinks]).
            const LegalLinks(),
          ],
        ),
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
            // ADR-010: burada YALNIZ girişin bu sürümde gerçekten
            // sağladığı şey yazılır. Eskiden "kütüphaneni ve favorilerini
            // senkronize et" deniyordu; oysa mobilde kütüphane/favori
            // ekranı YOK ve ortak sözleşmede de bir kütüphane yüzeyi
            // tanımlı değil (`library`, şemada yalnız bir hesap SİLME
            // etkisi olarak geçiyor). Kullanıcıya var olmayan bir özellik
            // vaat edilmez; kütüphane senkronu geldiğinde bu metin
            // güncellenecek.
            Text(
              'Hesabına giriş yaparak profilini ve oturumlarını yönet.',
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
