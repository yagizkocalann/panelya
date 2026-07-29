import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/core/config/auth_feature_config.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/account/data/fake_account_repository.dart';
import 'package:panelya_mobile/features/account/domain/account_deletion_summary.dart';
import 'package:panelya_mobile/features/account/domain/account_exceptions.dart';
import 'package:panelya_mobile/features/account/domain/account_provider.dart';
import 'package:panelya_mobile/features/account/domain/account_repository.dart';
import 'package:panelya_mobile/features/account/domain/account_session.dart';
import 'package:panelya_mobile/features/account/domain/blocked_account.dart';
import 'package:panelya_mobile/features/account/presentation/account_providers.dart';
import 'package:panelya_mobile/features/account/presentation/blocked_accounts_screen.dart';
import 'package:panelya_mobile/features/auth/domain/auth_repository.dart';
import 'package:panelya_mobile/features/auth/domain/auth_session_state.dart';
import 'package:panelya_mobile/features/auth/presentation/auth_providers.dart';
import 'package:panelya_mobile/shared/widgets/state_views.dart';

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

class _NeverResolvingAccountRepository implements AccountRepository {
  @override
  Future<AccountProvider> fetchSignInProvider() =>
      Completer<AccountProvider>().future;

  @override
  Future<void> updateProfile({required String displayName}) =>
      throw UnimplementedError();

  @override
  Future<void> requestEmailChange({required String newEmail}) =>
      throw UnimplementedError();

  @override
  Future<void> requestPasswordReset() => throw UnimplementedError();

  @override
  Future<List<AccountSession>> listSessions() => throw UnimplementedError();

  @override
  Future<void> revokeSession(String sessionId) => throw UnimplementedError();

  @override
  Future<void> revokeOtherSessions() => throw UnimplementedError();

  @override
  Future<List<BlockedAccount>> listBlockedAccounts() =>
      Completer<List<BlockedAccount>>().future;

  @override
  Future<void> unblockAccount(String blockedAccountId) =>
      throw UnimplementedError();

  @override
  Future<AccountDeletionSummary> fetchDeletionSummary() =>
      throw UnimplementedError();

  @override
  Future<void> deleteAccount({required String reauthCredential}) =>
      throw UnimplementedError();
}

const _blockedOne = BlockedAccount(id: 'b-1', displayName: 'Ahmet Kaya');
const _blockedTwo = BlockedAccount(id: 'b-2', displayName: 'Zeynep Demir');

Widget _wrap({required AccountRepository accountRepository}) {
  final router = GoRouter(
    initialLocation: '/account/blocked',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/account/blocked',
        builder: (context, state) => const BlockedAccountsScreen(),
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
      _wrap(accountRepository: _NeverResolvingAccountRepository()),
    );
    await tester.pump();

    expect(find.byType(AppLoadingView), findsOneWidget);
  });

  testWidgets(
    'liste getirilemezse AppErrorView + Tekrar dene gösterir',
    (tester) async {
      final repository = FakeAccountRepository()
        ..listBlockedAccountsError = Exception('boom');

      await tester.pumpWidget(_wrap(accountRepository: repository));
      await tester.pumpAndSettle();

      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
    },
  );

  testWidgets('hiç engellenen hesap yoksa boş durum mesajı gösterir', (
    tester,
  ) async {
    final repository = FakeAccountRepository(blockedAccounts: const []);
    await tester.pumpWidget(_wrap(accountRepository: repository));
    await tester.pumpAndSettle();

    expect(find.byType(AppEmptyView), findsOneWidget);
    expect(find.text('Engellediğin hesap yok.'), findsOneWidget);
  });

  testWidgets('engellenen hesaplar listelenir', (tester) async {
    final repository = FakeAccountRepository(
      blockedAccounts: [_blockedOne, _blockedTwo],
    );
    await tester.pumpWidget(_wrap(accountRepository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Ahmet Kaya'), findsOneWidget);
    expect(find.text('Zeynep Demir'), findsOneWidget);
    expect(find.text('Engeli kaldır'), findsNWidgets(2));
  });

  testWidgets(
    '"Engeli kaldır"a dokunmak unblockAccount\'ı çağırır ve satırı kaldırır',
    (tester) async {
      final repository = FakeAccountRepository(
        blockedAccounts: [_blockedOne, _blockedTwo],
      );
      await tester.pumpWidget(_wrap(accountRepository: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Engeli kaldır').first);
      await tester.pumpAndSettle();

      expect(repository.calls, contains('unblockAccount:b-1'));
      expect(find.text('Ahmet Kaya'), findsNothing);
      expect(find.text('Zeynep Demir'), findsOneWidget);
    },
  );

  testWidgets(
    'unblockAccount başarısız olursa SnackBar gösterilir, satır kalır',
    (tester) async {
      final repository = FakeAccountRepository(
        blockedAccounts: [_blockedOne],
      )..unblockAccountError = const AccountUnexpectedException(
        'Engel kaldırılamadı.',
      );
      await tester.pumpWidget(_wrap(accountRepository: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Engeli kaldır'));
      await tester.pumpAndSettle();

      expect(find.text('Engel kaldırılamadı.'), findsOneWidget);
      expect(find.text('Ahmet Kaya'), findsOneWidget);
    },
  );

  testWidgets(
    'the app bar offers a home button that navigates to "/" and meets the '
    '44x44 touch target minimum',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          accountRepository: FakeAccountRepository(
            blockedAccounts: [_blockedOne],
          ),
        ),
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
