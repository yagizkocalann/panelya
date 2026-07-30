import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/core/storage/token_store.dart';
import 'package:panelya_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:panelya_mobile/features/auth/domain/auth_exceptions.dart';
import 'package:panelya_mobile/features/auth/domain/auth_repository.dart';
import 'package:panelya_mobile/features/auth/domain/auth_session_state.dart';

/// [FakeAuthRepository] sınır testleri (bkz. PLAN "FakeAuthRepository durum
/// akışı: anonim→login→refresh→revoke").
///
/// [beginSignIn]'in ürettiği `state`/PKCE `code_challenge` yalnız
/// repository içinde tutulur (bkz. `auth_repository.dart` dokümantasyonu);
/// bu testler gerçek bir sistem tarayıcısı simüle etmek için
/// [AuthorizationRequest.authorizationUrl]'deki `state` query parametresini
/// okuyup aynı değeri callback URI'sine geri koyar — tıpkı gerçek bir Auth0
/// yönlendirmesinin yapacağı gibi.
Uri _successfulCallback(AuthorizationRequest request, {String code = 'fake-code'}) {
  final state = request.authorizationUrl.queryParameters['state']!;
  return Uri.parse('panelya://auth/callback?code=$code&state=$state');
}

void main() {
  group('FakeAuthRepository — anonim→login→refresh→revoke akışı', () {
    test('starts anonymous', () {
      final repo = FakeAuthRepository();
      expect(repo.currentState, const AuthSessionState.anonymous());
      expect(repo.currentState.isAuthenticated, isFalse);
      repo.dispose();
    });

    test(
      'beginSignIn + completeSignIn moves the session to authenticated '
      'and the state stream reflects the transition in order',
      () async {
        final repo = FakeAuthRepository();
        addTearDown(repo.dispose);

        final states = <AuthSessionState>[];
        final subscription = repo.stateChanges.listen(states.add);
        addTearDown(subscription.cancel);

        final request = await repo.beginSignIn();
        expect(request.callbackUrlScheme, 'panelya');
        expect(
          request.authorizationUrl.queryParameters['code_challenge_method'],
          'S256',
        );

        await repo.completeSignIn(_successfulCallback(request));

        expect(repo.currentState.isAuthenticated, isTrue);
        expect(
          (repo.currentState as AuthAuthenticated).user.role,
          'reader',
        );

        // Broadcast akışı, dinleyici bağlandığı anki mevcut durumu (anonim)
        // önce, sonra gerçek geçişi yayar.
        await Future<void>.delayed(Duration.zero);
        expect(states.first, const AuthSessionState.anonymous());
        expect(states.last.isAuthenticated, isTrue);
      },
    );

    test(
      'sign-in persists tokens through the injected TokenStore boundary',
      () async {
        final tokenStore = InMemoryTokenStore();
        final repo = FakeAuthRepository(tokenStore: tokenStore);
        addTearDown(repo.dispose);

        expect(await tokenStore.read(), isNull);

        final request = await repo.beginSignIn();
        await repo.completeSignIn(_successfulCallback(request));

        final stored = await tokenStore.read();
        expect(stored, isNotNull);
        expect(stored!.tokenType, 'Bearer');
        expect(stored.expiresIn, 900);
        expect(stored.user.id, isNotEmpty);
      },
    );

    test(
      'refresh() rotates both access and refresh tokens and keeps the '
      'user authenticated',
      () async {
        final tokenStore = InMemoryTokenStore();
        final repo = FakeAuthRepository(tokenStore: tokenStore);
        addTearDown(repo.dispose);

        final request = await repo.beginSignIn();
        await repo.completeSignIn(_successfulCallback(request));
        final beforeRefresh = await tokenStore.read();

        await repo.refresh();
        final afterRefresh = await tokenStore.read();

        expect(repo.currentState.isAuthenticated, isTrue);
        expect(afterRefresh!.accessToken, isNot(beforeRefresh!.accessToken));
        expect(afterRefresh.refreshToken, isNot(beforeRefresh.refreshToken));
        expect(afterRefresh.user.id, beforeRefresh.user.id);
      },
    );

    test('refresh() without an active session throws '
        'AuthNotAuthenticatedException', () async {
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      expect(
        () => repo.refresh(),
        throwsA(isA<AuthNotAuthenticatedException>()),
      );
    });

    test(
      'logout()/revoke clears the TokenStore and returns the session to '
      'anonymous',
      () async {
        final tokenStore = InMemoryTokenStore();
        final repo = FakeAuthRepository(tokenStore: tokenStore);
        addTearDown(repo.dispose);

        final request = await repo.beginSignIn();
        await repo.completeSignIn(_successfulCallback(request));
        expect(repo.currentState.isAuthenticated, isTrue);

        await repo.logout();

        expect(repo.currentState, const AuthSessionState.anonymous());
        expect(await tokenStore.read(), isNull);
      },
    );

    test('logout() while already anonymous is a safe no-op', () async {
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await repo.logout();

      expect(repo.currentState, const AuthSessionState.anonymous());
    });
  });

  group('FakeAuthRepository — callback bütünlük hataları', () {
    test('completeSignIn without a prior beginSignIn throws '
        'AuthCallbackException', () async {
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      expect(
        () => repo.completeSignIn(
          Uri.parse('panelya://auth/callback?code=x&state=y'),
        ),
        throwsA(isA<AuthCallbackException>()),
      );
    });

    test('a callback URI that is not panelya://auth/callback is rejected '
        'even mid-flow', () async {
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await repo.beginSignIn();

      expect(
        () => repo.completeSignIn(Uri.parse('panelya://series/some-slug')),
        throwsA(isA<AuthCallbackException>()),
      );
    });

    test('a state mismatch (CSRF) is rejected and the session stays '
        'anonymous', () async {
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await repo.beginSignIn();

      expect(
        () => repo.completeSignIn(
          Uri.parse('panelya://auth/callback?code=x&state=wrong-state'),
        ),
        throwsA(isA<AuthCallbackException>()),
      );
      expect(repo.currentState, const AuthSessionState.anonymous());
    });

    test('a missing code parameter is rejected', () async {
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      final request = await repo.beginSignIn();
      final state = request.authorizationUrl.queryParameters['state'];

      expect(
        () => repo.completeSignIn(
          Uri.parse('panelya://auth/callback?state=$state'),
        ),
        throwsA(isA<AuthCallbackException>()),
      );
    });

    test('user cancellation (error=access_denied) surfaces as '
        'AuthUserCancelledException', () async {
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      final request = await repo.beginSignIn();
      final state = request.authorizationUrl.queryParameters['state'];

      expect(
        () => repo.completeSignIn(
          Uri.parse(
            'panelya://auth/callback?error=access_denied&state=$state',
          ),
        ),
        throwsA(isA<AuthUserCancelledException>()),
      );
      expect(repo.currentState, const AuthSessionState.anonymous());
    });

    test('another provider error surfaces as AuthProviderErrorException', () async {
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      final request = await repo.beginSignIn();
      final state = request.authorizationUrl.queryParameters['state'];

      expect(
        () => repo.completeSignIn(
          Uri.parse(
            'panelya://auth/callback?error=server_error&state=$state',
          ),
        ),
        throwsA(isA<AuthProviderErrorException>()),
      );
    });

    test(
      'a pending sign-in request can only be completed once '
      '(replay of the same callback is rejected the second time)',
      () async {
        final repo = FakeAuthRepository();
        addTearDown(repo.dispose);

        final request = await repo.beginSignIn();
        final callback = _successfulCallback(request);

        await repo.completeSignIn(callback);

        expect(
          () => repo.completeSignIn(callback),
          throwsA(isA<AuthCallbackException>()),
        );
      },
    );
  });
}
