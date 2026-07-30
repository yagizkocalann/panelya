import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/core/config/account_management_feature_config.dart';
import 'package:panelya_mobile/core/config/auth_feature_config.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/account/data/fake_account_repository.dart';
import 'package:panelya_mobile/features/account/domain/account_repository.dart';
import 'package:panelya_mobile/features/account/presentation/account_home_screen.dart';
import 'package:panelya_mobile/features/account/presentation/account_providers.dart';
import 'package:panelya_mobile/features/auth/domain/auth_repository.dart';
import 'package:panelya_mobile/features/auth/domain/auth_session_state.dart';
import 'package:panelya_mobile/features/auth/presentation/auth_providers.dart';
import 'package:panelya_mobile/shared/widgets/state_views.dart';

import '../../../support/account_test_doubles.dart';

import '../../../support/overflow_watcher.dart';

const _fakeUser = AuthUser(
  id: 'user-1',
  displayName: 'Ece Yılmaz',
  email: 'ece@example.invalid',
  emailVerified: true,
  role: 'reader',
);

/// [AccountHomeScreen], `authSessionProvider` üzerinden gerçek oturum
/// kullanıcısını okur (bkz. `AccountOverview`'in dokümantasyonu — sahte
/// bir kimlik ASLA üretilmez); bu yüzden bu testler de gerçek
/// `AuthRepository` sözleşmesini uygulayan minimal bir sahte kullanır.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({AuthSessionState? initialState, this.logoutError})
    : _state = initialState ?? const AuthSessionState.authenticated(_fakeUser);

  /// Kuruldugunda `logout()` bunu firlatir (ör. guvenli depolama hatasi).
  final Object? logoutError;

  AuthSessionState _state;
  final _controller = StreamController<AuthSessionState>.broadcast();
  final List<String> logoutCalls = [];

  @override
  AuthSessionState get currentState => _state;

  @override
  Stream<AuthSessionState> get stateChanges async* {
    yield _state;
    yield* _controller.stream;
  }

  void _emit(AuthSessionState next) {
    _state = next;
    _controller.add(next);
  }

  @override
  Future<AuthorizationRequest> beginSignIn() => throw UnimplementedError();

  @override
  Future<void> completeSignIn(Uri callbackUri) => throw UnimplementedError();

  @override
  Future<void> refresh() => throw UnimplementedError();

  @override
  Future<void> logout() async {
    logoutCalls.add('logout');
    if (logoutError != null) throw logoutError!;
    _emit(const AuthSessionState.anonymous());
  }

  @override
  void dispose() {
    _controller.close();
  }
}

Widget _wrap({
  required AccountRepository accountRepository,
  _FakeAuthRepository? authRepository,
  double? textScale,
  // Testlerin çoğu hesap YÖNETİMİ ekranlarını doğruladığı için varsayılan
  // `true`dur; kapalı-bayrak (production varsayılanı) davranışı ayrı bir
  // grupta açıkça `false` verilerek doğrulanır (bkz. "hesap yönetimi
  // kapalıyken" grubu).
  bool managementEnabled = true,
}) {
  final router = GoRouter(
    initialLocation: '/account',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) =>
            const Scaffold(body: AccountHomeScreen()),
      ),
      GoRoute(
        path: '/account/profile',
        builder: (context, state) =>
            const Scaffold(body: Text('PROFILE_SCREEN')),
      ),
      GoRoute(
        path: '/account/security',
        builder: (context, state) =>
            const Scaffold(body: Text('SECURITY_SCREEN')),
      ),
      GoRoute(
        path: '/account/sessions',
        builder: (context, state) =>
            const Scaffold(body: Text('SESSIONS_SCREEN')),
      ),
      GoRoute(
        path: '/account/blocked',
        builder: (context, state) =>
            const Scaffold(body: Text('BLOCKED_SCREEN')),
      ),
      GoRoute(
        path: '/account/delete',
        builder: (context, state) =>
            const Scaffold(body: Text('DELETE_SCREEN')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authFeatureConfigProvider.overrideWithValue(
        const AuthFeatureConfig(enabled: true),
      ),
      accountManagementFeatureConfigProvider.overrideWithValue(
        AccountManagementFeatureConfig(enabled: managementEnabled),
      ),
      authRepositoryProvider.overrideWithValue(
        authRepository ?? _FakeAuthRepository(),
      ),
      accountRepositoryProvider.overrideWithValue(accountRepository),
    ],
    child: MaterialApp.router(
      theme: buildAppTheme(),
      routerConfig: router,
      builder: textScale == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
    ),
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
    'sağlayıcı bilgisi getirilemezse AppErrorView + Tekrar dene gösterir',
    (tester) async {
      final repository = FakeAccountRepository(user: _fakeUser)
        ..fetchOverviewError = Exception('boom');

      await tester.pumpWidget(_wrap(accountRepository: repository));
      await tester.pumpAndSettle();

      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text('Beklenmeyen bir hata oluştu.'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
    },
  );

  testWidgets(
    'database sağlayıcısıyla girişte ad/e-posta/doğrulanma/sağlayıcı '
    'etiketi ve tüm gezinme satırları gösterilir',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          accountRepository: FakeAccountRepository(
            provider: AccountProviderKind.database,
            user: _fakeUser,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ece Yılmaz'), findsOneWidget);
      expect(find.text('ece@example.invalid'), findsOneWidget);
      expect(
        find.text('E-posta ve şifre ile giriş yaptın.'),
        findsOneWidget,
      );
      expect(find.text('Profil'), findsOneWidget);
      expect(find.text('E-posta ve şifre'), findsOneWidget);
      expect(find.text('Aktif oturumlar'), findsOneWidget);
      expect(find.text('Engellenen hesaplar'), findsOneWidget);
      expect(find.text('Hesabı sil'), findsOneWidget);
      expect(find.text('Çıkış yap'), findsOneWidget);
    },
  );

  testWidgets(
    'google sağlayıcısıyla girişte "Google ile giriş yaptın." etiketi '
    'gösterilir',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          accountRepository: FakeAccountRepository(
            provider: AccountProviderKind.google,
            user: _fakeUser,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Google ile giriş yaptın.'), findsOneWidget);
    },
  );

  testWidgets('"Profil" satırına dokunmak /account/profile\'a gider', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(accountRepository: FakeAccountRepository(user: _fakeUser)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    expect(find.text('PROFILE_SCREEN'), findsOneWidget);
  });

  testWidgets(
    '"E-posta ve şifre" satırına dokunmak /account/security\'e gider',
    (tester) async {
      await tester.pumpWidget(
        _wrap(accountRepository: FakeAccountRepository(user: _fakeUser)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('E-posta ve şifre'));
      await tester.pumpAndSettle();

      expect(find.text('SECURITY_SCREEN'), findsOneWidget);
    },
  );

  testWidgets(
    '"Aktif oturumlar" satırına dokunmak /account/sessions\'a gider',
    (tester) async {
      await tester.pumpWidget(
        _wrap(accountRepository: FakeAccountRepository(user: _fakeUser)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aktif oturumlar'));
      await tester.pumpAndSettle();

      expect(find.text('SESSIONS_SCREEN'), findsOneWidget);
    },
  );

  testWidgets(
    '"Engellenen hesaplar" satırına dokunmak /account/blocked\'a gider',
    (tester) async {
      await tester.pumpWidget(
        _wrap(accountRepository: FakeAccountRepository(user: _fakeUser)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Engellenen hesaplar'));
      await tester.pumpAndSettle();

      expect(find.text('BLOCKED_SCREEN'), findsOneWidget);
    },
  );

  testWidgets('"Hesabı sil" satırına dokunmak /account/delete\'e gider', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(accountRepository: FakeAccountRepository(user: _fakeUser)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hesabı sil'));
    await tester.pumpAndSettle();

    expect(find.text('DELETE_SCREEN'), findsOneWidget);
  });

  testWidgets('"Çıkış yap" gerçek logout\'u çağırır', (tester) async {
    final authRepository = _FakeAuthRepository();
    await tester.pumpWidget(
      _wrap(
        accountRepository: FakeAccountRepository(user: _fakeUser),
        authRepository: authRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Çıkış yap'));
    await tester.pumpAndSettle();

    expect(authRepository.logoutCalls, hasLength(1));
  });

  testWidgets(
    'cikis basarisiz olursa buton spinner\'da KILITLENMEZ ve sebep '
    'gosterilir',
    (tester) async {
      final authRepository = _FakeAuthRepository(
        logoutError: Exception('yerel temizlik basarisiz'),
      );
      await tester.pumpWidget(
        _wrap(
          accountRepository: FakeAccountRepository(user: _fakeUser),
          authRepository: authRepository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Çıkış yap'));
      await tester.pumpAndSettle();

      expect(authRepository.logoutCalls, hasLength(1));
      // `finally` mesgul bayragini sifirladi: buton yine tiklanabilir.
      expect(find.text('Çıkış yap'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // Sahte basari YOK, durust mesaj VAR.
      expect(find.text('Çıkış yapılamadı. Tekrar dene.'), findsOneWidget);
    },
  );

  testWidgets(
    'uzun bir görünen adla scale=2.0\'da hiçbir taşma oluşmaz',
    (tester) async {
      final watcher = OverflowWatcher()..start();
      addTearDown(watcher.stop);

      const longNameUser = AuthUser(
        id: 'user-2',
        displayName:
            'Çok Uzun Bir Görünen Ad Örneği Taşma Testi İçin Yazıldı',
        email: 'cok-uzun-bir-eposta-adresi-ornegi@example.invalid',
        emailVerified: false,
        role: 'reader',
      );

      await tester.pumpWidget(
        _wrap(
          accountRepository: FakeAccountRepository(user: _fakeUser),
          authRepository: _FakeAuthRepository(
            initialState: const AuthSessionState.authenticated(
              longNameUser,
            ),
          ),
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(watcher.errors, isEmpty, reason: watcher.describe());
    },
  );

  /// Web tarafının açık yayın-koruma talimatı: `AUTH_ENABLED=true` (gerçek
  /// Auth0 girişi hazır) + `ACCOUNT_MANAGEMENT_ENABLED=false` (production
  /// varsayılanı) kombinasyonunda gerçek oturum bilgisi ve çıkış çalışmalı,
  /// sahte hesap yönetimi ekranları ise ERİŞİLEMEZ olmalı.
  group('hesap yönetimi kapalıyken (ACCOUNT_MANAGEMENT_ENABLED=false)', () {
    testWidgets(
      'gerçek kullanıcı bilgisi ve "Çıkış yap" gösterilir',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            accountRepository: FakeAccountRepository(user: _fakeUser),
            managementEnabled: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Ece Yılmaz'), findsOneWidget);
        expect(find.text('ece@example.invalid'), findsOneWidget);
        expect(find.text('Çıkış yap'), findsOneWidget);
      },
    );

    testWidgets(
      'beş yönetim girişi HİÇ render edilmez — devre dışı buton veya '
      '"yakında" placeholder olarak DA gösterilmez (ADR-010)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            accountRepository: FakeAccountRepository(user: _fakeUser),
            managementEnabled: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Profil'), findsNothing);
        expect(find.text('E-posta ve şifre'), findsNothing);
        expect(find.text('Aktif oturumlar'), findsNothing);
        expect(find.text('Engellenen hesaplar'), findsNothing);
        expect(find.text('Hesabı sil'), findsNothing);
        // "yakında"/devre dışı placeholder da yok:
        expect(find.textContaining('yakında'), findsNothing);
        expect(find.textContaining('Yakında'), findsNothing);
      },
    );

    testWidgets(
      'sahte sağlayıcı etiketi gösterilmez (o bilgi yalnız hesap '
      'repository\'sinden gelirdi)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            accountRepository: FakeAccountRepository(user: _fakeUser),
            managementEnabled: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('E-posta ve şifre ile giriş yaptın.'), findsNothing);
        expect(find.text('Google ile giriş yaptın.'), findsNothing);
      },
    );

    testWidgets(
      'accountRepositoryProvider HİÇ OKUNMAZ — bu yüzden gerçek runtime\'da '
      'bağlanmamış olması (fırlatan provider) ekranı bozmaz',
      (tester) async {
        // `accountRepositoryProvider` KASITLI OLARAK override EDİLMEZ:
        // gerçek runtime'daki gibi okunduğunda fırlatan hâliyle bırakılır.
        // Ekran yine de sorunsuz render olmalı.
        final authRepository = _FakeAuthRepository();
        final router = GoRouter(
          initialLocation: '/account',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Scaffold(body: Text('HOME')),
            ),
            GoRoute(
              path: '/account',
              builder: (context, state) =>
                  const Scaffold(body: AccountHomeScreen()),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authFeatureConfigProvider.overrideWithValue(
                const AuthFeatureConfig(enabled: true),
              ),
              accountManagementFeatureConfigProvider.overrideWithValue(
                const AccountManagementFeatureConfig(enabled: false),
              ),
              authRepositoryProvider.overrideWithValue(authRepository),
            ],
            child: MaterialApp.router(
              theme: buildAppTheme(),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Ece Yılmaz'), findsOneWidget);
        expect(find.text('Çıkış yap'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('gerçek çıkış hâlâ çalışır', (tester) async {
      final authRepository = _FakeAuthRepository();
      await tester.pumpWidget(
        _wrap(
          accountRepository: FakeAccountRepository(user: _fakeUser),
          authRepository: authRepository,
          managementEnabled: false,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Çıkış yap'));
      await tester.pumpAndSettle();

      expect(authRepository.logoutCalls, hasLength(1));
    });
  });
}
