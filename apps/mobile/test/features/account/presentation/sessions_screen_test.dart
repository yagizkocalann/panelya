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
import 'package:panelya_mobile/features/account/presentation/sessions_screen.dart';
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
  AuthSessionState _state = const AuthSessionState.authenticated(_fakeUser);
  final _controller = StreamController<AuthSessionState>.broadcast();
  final List<String> logoutCalls = [];

  @override
  AuthSessionState get currentState => _state;

  @override
  Stream<AuthSessionState> get stateChanges async* {
    yield _state;
    yield* _controller.stream;
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
    _state = const AuthSessionState.anonymous();
    _controller.add(_state);
  }

  @override
  void dispose() {
    _controller.close();
  }
}

/// Sözleşmede `lastActiveAt` bir ISO-8601 STRING'dir (DateTime değil).
const _fixedTimestamp = '2030-01-01T12:00:00.000Z';

final _currentSession = testSession(
  id: 's-current',
  deviceLabel: 'Bu cihaz — Android',
  lastActiveAt: _fixedTimestamp,
  current: true,
);

final _otherSession = testSession(
  id: 's-web',
  deviceLabel: 'Chrome — Windows',
  platform: AccountSessionPlatform.web,
  lastActiveAt: _fixedTimestamp,
);

Widget _wrap({
  required AccountRepository accountRepository,
  _FakeAuthRepository? authRepository,
}) {
  final router = GoRouter(
    initialLocation: '/account/sessions',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/account/sessions',
        builder: (context, state) => const SessionsScreen(),
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

  testWidgets('oturum listesi getirilemezse AppErrorView + Tekrar dene gösterir', (
    tester,
  ) async {
    final repository = FakeAccountRepository()
      ..fetchSessionsError = Exception('boom');

    await tester.pumpWidget(_wrap(accountRepository: repository));
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorView), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
  });

  testWidgets(
    'yükleme hatası sözleşmenin yapılandırılmış gövdesiyse SUNUCUNUN '
    'kendi açıklaması gösterilir, genel metinle örtülmez',
    (tester) async {
      final repository = FakeAccountRepository()
        ..fetchSessionsError = AccountServerException(
          const AccountErrorResponse(
            schemaVersion: kSchemaVersion,
            error: 'service_unavailable',
            errorDescription:
                'Oturum listesi şu an hazırlanamıyor (sunucu mesajı).',
            reauthenticate: false,
          ),
        );

      await tester.pumpWidget(_wrap(accountRepository: repository));
      await tester.pumpAndSettle();

      expect(
        find.text('Oturum listesi şu an hazırlanamıyor (sunucu mesajı).'),
        findsOneWidget,
      );
      expect(find.text('Beklenmeyen bir hata oluştu.'), findsNothing);
    },
  );

  testWidgets('hiç oturum yoksa boş durum mesajı gösterir', (tester) async {
    final repository = FakeAccountRepository(sessions: const []);
    await tester.pumpWidget(_wrap(accountRepository: repository));
    await tester.pumpAndSettle();

    expect(find.byType(AppEmptyView), findsOneWidget);
    expect(find.text('Aktif oturum bulunamadı.'), findsOneWidget);
  });

  testWidgets(
    'oturum listesi gösterilir, mevcut cihaz "Bu cihaz" rozetiyle işaretlenir',
    (tester) async {
      final repository = FakeAccountRepository(
        sessions: [_currentSession, _otherSession],
      );
      await tester.pumpWidget(_wrap(accountRepository: repository));
      await tester.pumpAndSettle();

      expect(find.text('Bu cihaz — Android'), findsOneWidget);
      expect(find.text('Chrome — Windows'), findsOneWidget);
      expect(find.text('Bu cihaz'), findsOneWidget);
      expect(find.text('Diğer tüm oturumları kapat'), findsOneWidget);
    },
  );

  testWidgets(
    'tek oturum varken "Diğer tüm oturumları kapat" HİÇ görünmez (ADR-010)',
    (tester) async {
      final repository = FakeAccountRepository(
        sessions: [_currentSession],
      );
      await tester.pumpWidget(_wrap(accountRepository: repository));
      await tester.pumpAndSettle();

      expect(find.text('Diğer tüm oturumları kapat'), findsNothing);
    },
  );

  testWidgets(
    'mevcut cihaz DIŞINDAKİ bir oturumu kapatmak listeden kaldırır, '
    'yerel oturumu KAPATMAZ',
    (tester) async {
      final authRepository = _FakeAuthRepository();
      final repository = FakeAccountRepository(
        sessions: [_currentSession, _otherSession],
      );
      await tester.pumpWidget(
        _wrap(accountRepository: repository, authRepository: authRepository),
      );
      await tester.pumpAndSettle();

      final revokeButtons = find.byTooltip('Oturumu kapat');
      expect(revokeButtons, findsNWidgets(2));

      // İkinci satır ("Chrome — Windows", mevcut cihaz olmayan) kapatılır.
      await tester.tap(revokeButtons.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oturumu kapat').last);
      await tester.pumpAndSettle();

      expect(repository.calls, contains('revokeSession:s-web'));
      expect(find.text('Chrome — Windows'), findsNothing);
      expect(find.text('Bu cihaz — Android'), findsOneWidget);
      expect(authRepository.logoutCalls, isEmpty);
    },
  );

  testWidgets(
    'mevcut cihazın KENDİ oturumunu kapatmak yerel çıkışı da tetikler ve '
    'ana sayfaya döner',
    (tester) async {
      final authRepository = _FakeAuthRepository();
      final repository = FakeAccountRepository(
        sessions: [_currentSession],
      )
        // Yerel çıkış artık `isCurrentDevice`'dan TAHMİN EDİLMEZ; sunucunun
        // döndürdüğü `currentSessionRevoked` bayrağına bakılır.
        ..revokeSessionRevokesCurrent = true;
      await tester.pumpWidget(
        _wrap(accountRepository: repository, authRepository: authRepository),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Oturumu kapat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oturumu kapat').last);
      await tester.pumpAndSettle();

      expect(repository.calls, contains('revokeSession:s-current'));
      expect(authRepository.logoutCalls, hasLength(1));
      expect(find.text('HOME'), findsOneWidget);
    },
  );

  testWidgets(
    'oturum kapatma başarısız olursa SnackBar gösterilir, liste değişmez',
    (tester) async {
      final repository = FakeAccountRepository(
        sessions: [_currentSession, _otherSession],
      )..revokeSessionError = const AccountUnexpectedException(
        'Oturum kapatılamadı.',
      );
      await tester.pumpWidget(_wrap(accountRepository: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Oturumu kapat').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oturumu kapat').last);
      await tester.pumpAndSettle();

      expect(find.text('Oturum kapatılamadı.'), findsOneWidget);
      expect(find.text('Chrome — Windows'), findsOneWidget);
    },
  );

  testWidgets(
    'oturum kapatma dialogunda "Vazgeç" hiçbir şeyi değiştirmez',
    (tester) async {
      final repository = FakeAccountRepository(
        sessions: [_currentSession, _otherSession],
      );
      await tester.pumpWidget(_wrap(accountRepository: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Oturumu kapat').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();

      expect(repository.calls, isNot(contains('revokeSession:s-web')));
      expect(find.text('Chrome — Windows'), findsOneWidget);
    },
  );

  testWidgets(
    '"Diğer tüm oturumları kapat" mevcut cihaz hariç hepsini kapatır',
    (tester) async {
      final repository = FakeAccountRepository(
        sessions: [_currentSession, _otherSession],
      );
      await tester.pumpWidget(_wrap(accountRepository: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Diğer tüm oturumları kapat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('revokeSessions:others'));
      expect(find.text('Chrome — Windows'), findsNothing);
      expect(find.text('Bu cihaz — Android'), findsOneWidget);
    },
  );

  testWidgets(
    'BİLİNEN SINIR: scope=others sunucuda 503 fail-closed dönerse hata '
    'DÜRÜSTÇE gösterilir — sahte başarı gösterilmez, liste değişmez',
    (tester) async {
      final authRepository = _FakeAuthRepository();
      final repository = FakeAccountRepository(
        sessions: [_currentSession, _otherSession],
      )..revokeSessionsError = AccountServerException(
        const AccountErrorResponse(
          schemaVersion: kSchemaVersion,
          error: 'service_unavailable',
          errorDescription:
              'Bu cihazın oturumu eşlenemediği için diğer oturumlar şu an '
              'kapatılamıyor.',
          reauthenticate: false,
        ),
      );
      await tester.pumpWidget(
        _wrap(accountRepository: repository, authRepository: authRepository),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Diğer tüm oturumları kapat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();

      // Sunucunun gerçek mesajı gösterilir.
      expect(
        find.text(
          'Bu cihazın oturumu eşlenemediği için diğer oturumlar şu an '
          'kapatılamıyor.',
        ),
        findsOneWidget,
      );
      // Hiçbir oturum listeden düşmedi ve yerel çıkış TETİKLENMEDİ.
      expect(find.text('Chrome — Windows'), findsOneWidget);
      expect(find.text('Bu cihaz — Android'), findsOneWidget);
      expect(authRepository.logoutCalls, isEmpty);
    },
  );

  testWidgets(
    'the app bar offers a home button that navigates to "/" and meets the '
    '44x44 touch target minimum',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          accountRepository: FakeAccountRepository(
            sessions: [_currentSession],
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
