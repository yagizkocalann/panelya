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
import 'package:panelya_mobile/features/account/presentation/delete_account_screen.dart';
import 'package:panelya_mobile/features/auth/data/auth_browser.dart';
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

class _FakeAuthRepository implements AuthRepository {
  final List<String> logoutCalls = [];

  @override
  AuthSessionState get currentState =>
      const AuthSessionState.authenticated(_fakeUser);

  @override
  Stream<AuthSessionState> get stateChanges => Stream.value(currentState);

  /// Taze kimlik doğrulaması ARTIK `AuthRepository` üzerinden yapılmaz
  /// (bkz. `AccountReauthenticator`) — bu metotlar çağrılırsa test
  /// kasıtlı olarak patlar.
  @override
  Future<AuthorizationRequest> beginSignIn() => throw UnimplementedError();

  @override
  Future<void> completeSignIn(Uri callbackUri) => throw UnimplementedError();

  @override
  Future<void> refresh() => throw UnimplementedError();

  @override
  Future<void> logout() async => logoutCalls.add('logout');

  @override
  void dispose() {}
}

/// [callbackUri] `null` ise sistem tarayıcısının iptal edildiğini simüle
/// eder.
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
  _FakeAuthRepository? authRepository,
  AuthBrowser? authBrowser,
  double? textScale,
}) {
  final router = GoRouter(
    initialLocation: '/account/delete',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/account/delete',
        builder: (context, state) => const DeleteAccountScreen(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authFeatureConfigProvider.overrideWithValue(
        const AuthFeatureConfig(enabled: true),
      ),
      authRepositoryProvider.overrideWithValue(
        authRepository ?? _FakeAuthRepository(),
      ),
      authBrowserProvider.overrideWithValue(
        authBrowser ?? const _FakeAuthBrowser(callbackUri: null),
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
    'silme özeti getirilemezse AppErrorView + Tekrar dene gösterir',
    (tester) async {
      final repository = FakeAccountRepository()
        ..fetchDeletionSummaryError = Exception('boom');

      await tester.pumpWidget(_wrap(accountRepository: repository));
      await tester.pumpAndSettle();

      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
    },
  );

  testWidgets(
    'silinecek, anonimleştirilecek VE saklanacak listeleri sözleşmenin '
    'enum değerlerinden okunaklı metne çevrilerek gösterilir',
    (tester) async {
      await tester.pumpWidget(
        _wrap(accountRepository: FakeAccountRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Silinecekler'), findsOneWidget);
      expect(find.text('Kimlik bilgilerin (Auth0)'), findsOneWidget);
      expect(find.text('Profil bilgilerin'), findsOneWidget);

      expect(find.text('Anonimleştirilecekler'), findsOneWidget);
      expect(find.text('Topluluk katkıların'), findsOneWidget);

      // `retained` sözleşmede AYRI bir listedir; kullanıcı eksik bilgiyle
      // onay vermesin diye dürüstçe gösterilir.
      expect(find.text('Saklanacaklar'), findsOneWidget);
      expect(find.text('Yasal kayıtlar ve denetim izleri'), findsOneWidget);
    },
  );

  testWidgets(
    '1. adım diyalogunda "Vazgeç" hiçbir şey yapmaz, taze kimlik '
    'doğrulaması başlatılmaz',
    (tester) async {
      final accountRepository = FakeAccountRepository();
      await tester.pumpWidget(_wrap(accountRepository: accountRepository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hesabımı sil'));
      await tester.pumpAndSettle();
      expect(
        find.text('Hesabını silmek istediğine emin misin?'),
        findsOneWidget,
      );

      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();

      expect(
        accountRepository.calls,
        isNot(contains('startReauthentication:account_deletion')),
      );
      expect(accountRepository.calls, isNot(contains('deleteAccount')));
    },
  );

  testWidgets(
    '1. adım onaylanıp 2. adımda "Vazgeç" denirse yine hiçbir şey yapılmaz',
    (tester) async {
      final accountRepository = FakeAccountRepository();
      await tester.pumpWidget(_wrap(accountRepository: accountRepository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hesabımı sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Devam et'));
      await tester.pumpAndSettle();

      expect(find.text('Bu işlem geri alınamaz'), findsOneWidget);

      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();

      expect(
        accountRepository.calls,
        isNot(contains('startReauthentication:account_deletion')),
      );
      expect(accountRepository.calls, isNot(contains('deleteAccount')));
    },
  );

  testWidgets(
    'her iki adım da onaylanınca start/complete reauth akışı çalışır ve '
    'silme YALNIZ dönen reauthenticationToken ile yapılır; authorization '
    'code mutation\'a DOĞRUDAN verilmez',
    (tester) async {
      final accountRepository = FakeAccountRepository();
      final authRepository = _FakeAuthRepository();
      await tester.pumpWidget(
        _wrap(
          accountRepository: accountRepository,
          authRepository: authRepository,
          authBrowser: _FakeAuthBrowser(callbackUri: _successfulCallback()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hesabımı sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Devam et'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Evet, hesabımı kalıcı olarak sil'));
      await tester.pumpAndSettle();

      // Sözleşmenin üç adımı da sırayla çağrıldı.
      expect(
        accountRepository.calls,
        containsAllInOrder([
          'startReauthentication:account_deletion',
          'completeReauthentication',
          'deleteAccount',
        ]),
      );
      // Mutation'a giden değer, callback'teki authorization code DEĞİL,
      // sunucudan dönen tek kullanımlık token.
      expect(
        accountRepository.lastDeletionToken,
        'fake-reauthentication-token-0000000000000000000000',
      );
      expect(accountRepository.lastDeletionToken, isNot('fresh-code'));
      // Mevcut oturum akışı (`beginSignIn`/`completeSignIn`) HİÇ
      // kullanılmadı — kullanılsaydı `UnimplementedError` fırlardı.
      expect(authRepository.logoutCalls, hasLength(1));
      expect(find.text('HOME'), findsOneWidget);
    },
  );

  testWidgets(
    'taze kimlik doğrulaması sistem tarayıcısında iptal edilirse silme '
    'HİÇ çağrılmaz, hata gösterilmez, ekranda kalınır',
    (tester) async {
      final accountRepository = FakeAccountRepository();
      final authRepository = _FakeAuthRepository();
      await tester.pumpWidget(
        _wrap(
          accountRepository: accountRepository,
          authRepository: authRepository,
          authBrowser: const _FakeAuthBrowser(callbackUri: null),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hesabımı sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Devam et'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Evet, hesabımı kalıcı olarak sil'));
      await tester.pumpAndSettle();

      expect(
        accountRepository.calls,
        contains('startReauthentication:account_deletion'),
      );
      expect(accountRepository.calls, isNot(contains('deleteAccount')));
      expect(authRepository.logoutCalls, isEmpty);
      expect(find.byType(AppErrorView), findsNothing);
      expect(find.text('Hesabımı sil'), findsOneWidget);
    },
  );

  testWidgets(
    'deleteAccount başarısız olursa SnackBar gösterilir, yerel oturum '
    'kapatılmaz, ekranda kalınır',
    (tester) async {
      final accountRepository = FakeAccountRepository()
        ..deleteAccountError = const AccountUnexpectedException(
          'Hesap silinemedi.',
        );
      final authRepository = _FakeAuthRepository();
      await tester.pumpWidget(
        _wrap(
          accountRepository: accountRepository,
          authRepository: authRepository,
          authBrowser: _FakeAuthBrowser(callbackUri: _successfulCallback()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hesabımı sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Devam et'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Evet, hesabımı kalıcı olarak sil'));
      await tester.pumpAndSettle();

      expect(find.text('Hesap silinemedi.'), findsOneWidget);
      expect(authRepository.logoutCalls, isEmpty);
      expect(find.text('Hesabımı sil'), findsOneWidget);
    },
  );

  testWidgets(
    'reauthentication sunucu hatası (ör. süresi dolmuş) dürüstçe '
    'gösterilir ve silme çağrılmaz',
    (tester) async {
      final accountRepository = FakeAccountRepository()
        ..startReauthenticationError = AccountServerException(
          const AccountErrorResponse(
            schemaVersion: kSchemaVersion,
            error: 'reauthentication_expired',
            errorDescription: 'Kimlik doğrulamanın süresi doldu.',
            reauthenticate: true,
          ),
        );
      await tester.pumpWidget(
        _wrap(
          accountRepository: accountRepository,
          authBrowser: _FakeAuthBrowser(callbackUri: _successfulCallback()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hesabımı sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Devam et'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Evet, hesabımı kalıcı olarak sil'));
      await tester.pumpAndSettle();

      expect(find.text('Kimlik doğrulamanın süresi doldu.'), findsOneWidget);
      expect(accountRepository.calls, isNot(contains('deleteAccount')));
    },
  );

  testWidgets(
    'uzun bir silme özetiyle scale=2.0\'da hiçbir taşma oluşmaz',
    (tester) async {
      final watcher = OverflowWatcher()..start();
      addTearDown(watcher.stop);

      await tester.pumpWidget(
        _wrap(
          accountRepository: FakeAccountRepository(
            deletionSummary: const AccountDeletionSummaryResponse(
              schemaVersion: kSchemaVersion,
              deleted: [
                AccountDeletionEffect.auth_identity,
                AccountDeletionEffect.profile,
                AccountDeletionEffect.active_sessions,
                AccountDeletionEffect.library,
                AccountDeletionEffect.reading_progress,
              ],
              anonymized: [AccountDeletionEffect.community_contributions],
              retained: [AccountDeletionEffect.legal_and_audit_records],
            ),
          ),
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(watcher.errors, isEmpty, reason: watcher.describe());
    },
  );

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
