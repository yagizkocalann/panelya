import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/core/config/auth_feature_config.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/account/data/fake_account_repository.dart';
import 'package:panelya_mobile/features/account/domain/account_exceptions.dart';
import 'package:panelya_mobile/features/account/domain/account_repository.dart';
import 'package:panelya_mobile/features/account/presentation/account_providers.dart';
import 'package:panelya_mobile/features/account/presentation/security_screen.dart';
import 'package:panelya_mobile/features/auth/data/auth_browser.dart';
import 'package:panelya_mobile/features/auth/domain/auth_repository.dart';
import 'package:panelya_mobile/features/auth/domain/auth_session_state.dart';
import 'package:panelya_mobile/features/auth/presentation/auth_providers.dart';
import 'package:panelya_mobile/shared/widgets/state_views.dart';

import '../../../support/account_test_doubles.dart';

const _fakeUser = AuthUser(
  id: 'user-1',
  displayName: 'Ece Yılmaz',
  email: 'ece@example.invalid',
  emailVerified: true,
  role: 'reader',
);

class _FakeAuthRepository implements AuthRepository {
  @override
  AuthSessionState get currentState =>
      const AuthSessionState.authenticated(_fakeUser);

  @override
  Stream<AuthSessionState> get stateChanges => Stream.value(currentState);

  @override
  Future<AuthorizationRequest> beginSignIn() => throw UnimplementedError();

  @override
  Future<void> completeSignIn(Uri callbackUri) => throw UnimplementedError();

  @override
  Future<void> refresh() => throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  void dispose() {}
}

/// Taze kimlik doğrulaması gerektiğinde sistem tarayıcısını simüle eder;
/// [callbackUri] `null` ise kullanıcı iptal etmiş sayılır.
class _FakeAuthBrowser implements AuthBrowser {
  const _FakeAuthBrowser({this.callbackUri});

  final Uri? callbackUri;

  @override
  Future<Uri?> authenticate({
    required Uri authorizationUrl,
    required String callbackUrlScheme,
  }) async => callbackUri;
}

Uri _successfulCallback() =>
    Uri.parse('panelya://auth/callback?code=fresh-code&state=fresh-state');

Widget _wrap({
  required AccountRepository accountRepository,
  AuthBrowser? authBrowser,
}) {
  final router = GoRouter(
    initialLocation: '/account/security',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/account/security',
        builder: (context, state) => const SecurityScreen(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authFeatureConfigProvider.overrideWithValue(
        const AuthFeatureConfig(enabled: true),
      ),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      authBrowserProvider.overrideWithValue(
        authBrowser ?? _FakeAuthBrowser(callbackUri: _successfulCallback()),
      ),
      accountRepositoryProvider.overrideWithValue(accountRepository),
    ],
    child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
  );
}

void main() {
  testWidgets('yüklenirken AppLoadingView gösterir', (tester) async {
    await tester.pumpWidget(
      _wrap(accountRepository: NeverResolvingAccountRepository()),
    );
    await tester.pump();

    expect(find.byType(AppLoadingView), findsOneWidget);
  });

  testWidgets(
    'hesap özeti getirilemezse AppErrorView + Tekrar dene gösterir',
    (tester) async {
      final repository = FakeAccountRepository()
        ..fetchOverviewError = Exception('boom');

      await tester.pumpWidget(_wrap(accountRepository: repository));
      await tester.pumpAndSettle();

      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
    },
  );

  group('database sağlayıcısı', () {
    testWidgets(
      'e-posta değiştirme ve şifre sıfırlama aksiyonlarının ikisi de '
      'gösterilir',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            accountRepository: FakeAccountRepository(
              provider: AccountProviderKind.database,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('E-postayı değiştir'), findsOneWidget);
        expect(find.text('Sıfırlama e-postası gönder'), findsOneWidget);
      },
    );

    testWidgets(
      'emailChange yeteneği "enabled" iken taze kimlik doğrulaması '
      'YAPILMADAN doğrudan requestEmailChange çağrılır',
      (tester) async {
        final repository = FakeAccountRepository(
          provider: AccountProviderKind.database,
          capabilities: testCapabilities(
            emailChange: AccountActionCapability.enabled,
          ),
        );
        await tester.pumpWidget(_wrap(accountRepository: repository));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField),
          'yeni-eposta@example.invalid',
        );
        await tester.tap(find.text('E-postayı değiştir'));
        await tester.pumpAndSettle();

        expect(repository.calls, contains('requestEmailChange'));
        expect(repository.lastRequestedEmail, 'yeni-eposta@example.invalid');
        expect(
          repository.calls,
          isNot(contains('startReauthentication:email_change')),
        );
        expect(
          find.text(
            'Doğrulama e-postası gönderildi. Gelen kutunu kontrol et.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'emailChange yeteneği "reauthentication_required" iken ÖNCE '
      'start/complete reauth akışı çalışır ve mutation\'a dönen token '
      'geçirilir (authorization code DEĞİL)',
      (tester) async {
        final repository = FakeAccountRepository(
          provider: AccountProviderKind.database,
          capabilities: testCapabilities(
            emailChange: AccountActionCapability.reauthentication_required,
          ),
        );
        await tester.pumpWidget(_wrap(accountRepository: repository));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField),
          'yeni-eposta@example.invalid',
        );
        await tester.tap(find.text('E-postayı değiştir'));
        await tester.pumpAndSettle();

        expect(
          repository.calls,
          containsAllInOrder([
            'startReauthentication:email_change',
            'completeReauthentication',
            'requestEmailChange',
          ]),
        );
        expect(
          repository.lastEmailChangeToken,
          'fake-reauthentication-token-0000000000000000000000',
        );
        expect(repository.lastEmailChangeToken, isNot('fresh-code'));
      },
    );

    testWidgets(
      'reauth gerektiğinde kullanıcı sistem tarayıcısını iptal ederse '
      'e-posta değiştirme HİÇ çağrılmaz ve hata gösterilmez',
      (tester) async {
        final repository = FakeAccountRepository(
          provider: AccountProviderKind.database,
          capabilities: testCapabilities(
            emailChange: AccountActionCapability.reauthentication_required,
          ),
        );
        await tester.pumpWidget(
          _wrap(
            accountRepository: repository,
            authBrowser: const _FakeAuthBrowser(callbackUri: null),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('E-postayı değiştir'));
        await tester.pumpAndSettle();

        expect(repository.calls, isNot(contains('requestEmailChange')));
        expect(
          find.text(
            'Doğrulama e-postası gönderildi. Gelen kutunu kontrol et.',
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'requestEmailChange başarısız olursa SnackBar ile hata gösterilir, '
      'onay paneli GÖRÜNMEZ',
      (tester) async {
        final repository = FakeAccountRepository(
          provider: AccountProviderKind.database,
          capabilities: testCapabilities(
            emailChange: AccountActionCapability.enabled,
          ),
        )..requestEmailChangeError = const AccountUnexpectedException(
          'E-posta değiştirilemedi.',
        );
        await tester.pumpWidget(_wrap(accountRepository: repository));
        await tester.pumpAndSettle();

        await tester.tap(find.text('E-postayı değiştir'));
        await tester.pumpAndSettle();

        expect(find.text('E-posta değiştirilemedi.'), findsOneWidget);
        expect(
          find.text(
            'Doğrulama e-postası gönderildi. Gelen kutunu kontrol et.',
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      '"Sıfırlama e-postası gönder"e dokunmak requestPasswordReset\'i '
      'çağırır ve onay paneli gösterir',
      (tester) async {
        final repository = FakeAccountRepository(
          provider: AccountProviderKind.database,
        );
        await tester.pumpWidget(_wrap(accountRepository: repository));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sıfırlama e-postası gönder'));
        await tester.pumpAndSettle();

        expect(repository.calls, contains('requestPasswordReset'));
        expect(
          find.text('Şifre sıfırlama e-postası gönderildi.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'requestPasswordReset başarısız olursa SnackBar ile hata gösterilir',
      (tester) async {
        final repository = FakeAccountRepository(
          provider: AccountProviderKind.database,
        )..requestPasswordResetError = const AccountUnexpectedException(
          'Sıfırlama e-postası gönderilemedi.',
        );
        await tester.pumpWidget(_wrap(accountRepository: repository));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sıfırlama e-postası gönder'));
        await tester.pumpAndSettle();

        expect(
          find.text('Sıfırlama e-postası gönderilemedi.'),
          findsOneWidget,
        );
      },
    );
  });

  group('google sağlayıcısı', () {
    testWidgets(
      'yalnız açıklayıcı metin gösterilir, HİÇBİR form alanı/butonu YOKTUR '
      '(ADR-010)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            accountRepository: FakeAccountRepository(
              provider: AccountProviderKind.google,
              capabilities: testCapabilities(
                emailChange: AccountActionCapability.provider_managed,
                passwordAction: AccountActionCapability.provider_managed,
                avatarEditing: AccountActionCapability.provider_managed,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Açıklama SAĞLAYICI-AGNOSTİKTİR: capability sözleşmesi yalnız
        // "provider_managed" der, hangi sağlayıcı olduğunu söylemez —
        // bu yüzden metin "giriş sağlayıcın" ifadesini kullanır.
        expect(
          find.textContaining('giriş sağlayıcın tarafından yönetiliyor'),
          findsNWidgets(2),
        );
        expect(find.byType(TextField), findsNothing);
        expect(find.text('E-postayı değiştir'), findsNothing);
        expect(find.text('Sıfırlama e-postası gönder'), findsNothing);
      },
    );
  });

  testWidgets(
    'the app bar offers a home button that navigates to "/" and meets the '
    '44x44 touch target minimum',
    (tester) async {
      await tester.pumpWidget(
        _wrap(accountRepository: FakeAccountRepository()),
      );
      await tester.pumpAndSettle();

      final homeButton = find.byTooltip('Ana sayfa');
      expect(homeButton, findsOneWidget);
      expect(tester.getSize(homeButton).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(homeButton).height, greaterThanOrEqualTo(44));

      await tester.tap(homeButton);
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
    },
  );
}
