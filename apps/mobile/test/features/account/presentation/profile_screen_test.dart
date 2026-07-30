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
import 'package:panelya_mobile/features/account/presentation/profile_screen.dart';
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

Widget _wrap({required AccountRepository accountRepository}) {
  final router = GoRouter(
    initialLocation: '/account/profile',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/account/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/account/security',
        builder: (context, state) =>
            const Scaffold(body: Text('SECURITY_SCREEN')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authFeatureConfigProvider.overrideWithValue(
        const AuthFeatureConfig(enabled: true),
      ),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
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
      final repository = FakeAccountRepository(user: _fakeUser)
        ..fetchOverviewError = Exception('boom');

      await tester.pumpWidget(_wrap(accountRepository: repository));
      await tester.pumpAndSettle();

      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
    },
  );

  testWidgets(
    'görünen ad alanı gerçek kullanıcı adıyla önceden doldurulur, avatar '
    'düzenleme İÇİN HİÇBİR düzenleme ikonu/butonu gösterilmez (ADR-010)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(accountRepository: FakeAccountRepository(user: _fakeUser)),
      );
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Ece Yılmaz');
      expect(find.text('ece@example.invalid'), findsOneWidget);
      expect(
        find.text('Profil fotoğrafı düzenleme bu sürümde desteklenmiyor.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.camera_alt), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
    },
  );

  testWidgets(
    '"Kaydet"e dokunmak updateProfile\'ı düzenlenmiş metinle çağırır',
    (tester) async {
      final repository = FakeAccountRepository(user: _fakeUser);
      await tester.pumpWidget(_wrap(accountRepository: repository));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Yeni Ad');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('updateProfile'));
      expect(repository.lastUpdatedDisplayName, 'Yeni Ad');
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'updateProfile başarısız olursa SnackBar ile hata mesajı gösterilir',
    (tester) async {
      final repository = FakeAccountRepository(user: _fakeUser)
        ..updateProfileError = const AccountUnexpectedException(
          'Kaydedilemedi.',
        );
      await tester.pumpWidget(_wrap(accountRepository: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(find.text('Kaydedilemedi.'), findsOneWidget);
    },
  );

  testWidgets('e-posta satırına dokunmak /account/security\'e gider', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(accountRepository: FakeAccountRepository(user: _fakeUser)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ece@example.invalid'));
    await tester.pumpAndSettle();

    expect(find.text('SECURITY_SCREEN'), findsOneWidget);
  });

  testWidgets(
    'the app bar offers a home button that navigates to "/" and meets the '
    '44x44 touch target minimum',
    (tester) async {
      await tester.pumpWidget(
        _wrap(accountRepository: FakeAccountRepository(user: _fakeUser)),
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
