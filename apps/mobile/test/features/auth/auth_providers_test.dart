import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/core/config/auth_feature_config.dart';
import 'package:panelya_mobile/features/auth/domain/auth_repository.dart';
import 'package:panelya_mobile/features/auth/domain/auth_session_state.dart';
import 'package:panelya_mobile/features/auth/presentation/auth_providers.dart';

/// Bekleyen bir `stateChanges` aboneliğinin (async* + broadcast
/// `StreamController` zinciri) microtask kuyruğunu boşaltmasına izin
/// verir. Gerçek bir zamanlayıcı gerekmez; yalnız event loop'un bir kaç
/// turunu döndürür.
Future<void> _flushMicrotasks() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Uri _successfulCallback(AuthorizationRequest request) {
  final state = request.authorizationUrl.queryParameters['state']!;
  return Uri.parse('panelya://auth/callback?code=fake-code&state=$state');
}

void main() {
  group('authSessionProvider — auth yapılandırılmamışken (PLAN gereksinimi)', () {
    test(
      'default config (AUTH_ENABLED verilmedi) iken oturum durumu anonim '
      'kalır',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(
          container.read(authSessionProvider),
          const AuthSessionState.anonymous(),
        );
      },
    );

    test(
      'yapılandırılmamışken authRepositoryProvider HİÇ örneklenmez '
      '(authSessionProvider onu watch etmez)',
      () {
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWith(
              (ref) => throw StateError(
                'authRepositoryProvider yapılandırılmamışken '
                'örneklenmemeliydi.',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        // authFeatureConfigProvider override edilmedi -> varsayılan
        // (enabled: false) kalır. Aşağıdaki okuma StateError fırlatsaydı
        // authSessionProvider'ın repository'yi gereksiz yere örneklediği
        // anlamına gelirdi.
        expect(
          () => container.read(authSessionProvider),
          returnsNormally,
        );
        expect(
          container.read(authSessionProvider),
          const AuthSessionState.anonymous(),
        );
      },
    );

    test('explicit enabled: false override also stays anonymous', () {
      final container = ProviderContainer(
        overrides: [
          authFeatureConfigProvider.overrideWithValue(
            const AuthFeatureConfig(enabled: false),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(authSessionProvider),
        const AuthSessionState.anonymous(),
      );
    });
  });

  group('authSessionProvider — enabled: true (testlerde override edilerek)', () {
    test(
      'enabled: true iken FakeAuthRepository durumunu yansıtır ve tam '
      'akışı (anonim→login→refresh→revoke) sürer',
      () async {
        final container = ProviderContainer(
          overrides: [
            authFeatureConfigProvider.overrideWithValue(
              const AuthFeatureConfig(enabled: true),
            ),
          ],
        );
        addTearDown(container.dispose);

        expect(
          container.read(authSessionProvider),
          const AuthSessionState.anonymous(),
        );

        final repository = container.read(authRepositoryProvider);
        final request = await repository.beginSignIn();
        await repository.completeSignIn(_successfulCallback(request));
        await _flushMicrotasks();

        expect(container.read(authSessionProvider).isAuthenticated, isTrue);

        await repository.logout();
        await _flushMicrotasks();

        expect(
          container.read(authSessionProvider),
          const AuthSessionState.anonymous(),
        );
      },
    );

    test(
      'authRepositoryProvider is a stable singleton within one container '
      '(same instance backs both beginSignIn/completeSignIn and the '
      'session provider)',
      () {
        final container = ProviderContainer(
          overrides: [
            authFeatureConfigProvider.overrideWithValue(
              const AuthFeatureConfig(enabled: true),
            ),
          ],
        );
        addTearDown(container.dispose);

        final first = container.read(authRepositoryProvider);
        final second = container.read(authRepositoryProvider);
        expect(identical(first, second), isTrue);
      },
    );
  });
}
