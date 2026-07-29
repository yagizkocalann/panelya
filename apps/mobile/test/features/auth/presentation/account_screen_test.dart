import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/core/config/auth_feature_config.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/account/data/fake_account_repository.dart';
import 'package:panelya_mobile/features/account/presentation/account_home_screen.dart';
import 'package:panelya_mobile/features/account/presentation/account_providers.dart';
import 'package:panelya_mobile/features/auth/data/auth_browser.dart';
import 'package:panelya_mobile/features/auth/domain/auth_exceptions.dart';
import 'package:panelya_mobile/features/auth/domain/auth_repository.dart';
import 'package:panelya_mobile/features/auth/domain/auth_session_state.dart';
import 'package:panelya_mobile/features/auth/presentation/account_screen.dart';
import 'package:panelya_mobile/features/auth/presentation/auth_providers.dart';
import 'package:panelya_mobile/shared/widgets/state_views.dart';

const _fakeUser = AuthUser(
  id: 'user-1',
  displayName: 'Ece Yılmaz',
  email: 'ece@example.invalid',
  emailVerified: true,
  role: 'reader',
);

/// Bu dosyanın amacı: `AccountScreen`nin gerçek `HttpAuthRepository`
/// tarafından üretilen üç sonucu (503/servis kullanılamıyor, kullanıcı
/// iptali, başarılı giriş) doğru render ettiğini doğrulamak. Gerçek
/// HTTP hiç çağrılmaz — bu sahte repository/browser çiftinin ürettiği
/// sonuçlar, `HttpAuthRepository`nin ADR-039 sözleşmesi gereği ÜRETMESİ
/// GEREKEN aynı istisna/durum tiplerini taklit eder.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({AuthSessionState? initialState})
    : _state = initialState ?? const AuthSessionState.anonymous();

  AuthSessionState _state;
  final _controller = StreamController<AuthSessionState>.broadcast();

  /// Ayarlanırsa `beginSignIn` bunu fırlatır (bkz. "servis kullanılamıyor"
  /// testi — `HttpAuthRepository.beginSignIn`nin gerçek 503'ü nasıl
  /// yüzeye çıkardığının aynısı).
  Object? beginSignInError;

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
  Future<AuthorizationRequest> beginSignIn() async {
    final error = beginSignInError;
    if (error != null) Error.throwWithStackTrace(error, StackTrace.current);
    return AuthorizationRequest(
      authorizationUrl: Uri.parse('https://example.invalid/authorize'),
      callbackUrlScheme: 'panelya',
    );
  }

  @override
  Future<void> completeSignIn(Uri callbackUri) async {
    _emit(const AuthSessionState.authenticated(_fakeUser));
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> logout() async {
    logoutCalls.add('logout');
    _emit(const AuthSessionState.anonymous());
  }

  @override
  void dispose() {
    _controller.close();
  }
}

/// [callbackUri] `null` ise sistem tarayıcısının iptal edildiğini
/// simüle eder (bkz. `AuthBrowser.authenticate` doc yorumu).
class _FakeAuthBrowser implements AuthBrowser {
  const _FakeAuthBrowser({this.callbackUri});

  final Uri? callbackUri;

  @override
  Future<Uri?> authenticate({
    required Uri authorizationUrl,
    required String callbackUrlScheme,
  }) async => callbackUri;
}

Widget _wrap({
  required _FakeAuthRepository repository,
  AuthBrowser? browser,
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
        builder: (context, state) => const AccountScreen(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authFeatureConfigProvider.overrideWithValue(
        const AuthFeatureConfig(enabled: true),
      ),
      authRepositoryProvider.overrideWithValue(repository),
      authBrowserProvider.overrideWithValue(
        browser ?? const _FakeAuthBrowser(callbackUri: null),
      ),
      // `AccountHomeScreen` (bkz. ADR-047), kimliği doğrulanmış durumda bu
      // ekranın gösterdiği içerik — kendi testleri
      // `test/features/account/presentation/account_home_screen_test.dart`ta;
      // burada yalnız `AccountScreen`in doğru ekrana DEVRETTİĞİNİ
      // doğrulamak için her zaman başarılı bir sahte kullanılır.
      accountRepositoryProvider.overrideWithValue(FakeAccountRepository()),
    ],
    child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
  );
}

void main() {
  testWidgets(
    'anonim durumda "Giriş yap" butonu gösterir, hata yok',
    (tester) async {
      await tester.pumpWidget(_wrap(repository: _FakeAuthRepository()));
      await tester.pumpAndSettle();

      expect(find.text('Giriş yap'), findsOneWidget);
      expect(find.byType(AppErrorView), findsNothing);
    },
  );

  testWidgets(
    'gerçek Auth0 tenant\'ı sağlanana kadar backend\'in dönmesi gereken '
    '503 (AuthProviderErrorException) dürüstçe AppErrorView olarak '
    'gösterilir — ADR-010 ihlali değil, doğru raporlanan bir '
    'kullanılamazlık durumu',
    (tester) async {
      final repository = _FakeAuthRepository()
        ..beginSignInError = AuthProviderErrorException(
          const AuthErrorResponse(
            schemaVersion: kSchemaVersion,
            error: 'service_unavailable',
            errorDescription: 'Servis şu an kullanılamıyor.',
            reauthenticate: false,
          ),
        );

      await tester.pumpWidget(_wrap(repository: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Giriş yap'));
      await tester.pumpAndSettle();

      expect(find.text('Servis şu an kullanılamıyor.'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
    },
  );

  testWidgets(
    'kullanıcı sistem tarayıcısını iptal ederse hata gösterilmez, anonim '
    'durumda kalır',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          repository: _FakeAuthRepository(),
          browser: const _FakeAuthBrowser(callbackUri: null),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Giriş yap'));
      await tester.pumpAndSettle();

      expect(find.byType(AppErrorView), findsNothing);
      expect(find.text('Giriş yap'), findsOneWidget);
    },
  );

  testWidgets(
    'başarılı giriş sonrası "Hesabım ana ekranı"na (AccountHomeScreen, '
    'bkz. ADR-047) devredilir',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          repository: _FakeAuthRepository(),
          browser: _FakeAuthBrowser(
            callbackUri: Uri.parse('panelya://auth/callback?code=x&state=y'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Giriş yap'));
      await tester.pumpAndSettle();

      expect(find.byType(AccountHomeScreen), findsOneWidget);
    },
  );

  testWidgets(
    '"Çıkış yap" logout\'u çağırır ve anonim duruma döner',
    (tester) async {
      final repository = _FakeAuthRepository(
        initialState: const AuthSessionState.authenticated(_fakeUser),
      );

      await tester.pumpWidget(_wrap(repository: repository));
      await tester.pumpAndSettle();

      expect(find.text('Çıkış yap'), findsOneWidget);

      await tester.tap(find.text('Çıkış yap'));
      await tester.pumpAndSettle();

      expect(repository.logoutCalls, hasLength(1));
      expect(find.text('Giriş yap'), findsOneWidget);
    },
  );

  testWidgets(
    'the app bar offers a home button that navigates to "/" and meets the '
    '44x44 touch target minimum',
    (tester) async {
      await tester.pumpWidget(_wrap(repository: _FakeAuthRepository()));
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
