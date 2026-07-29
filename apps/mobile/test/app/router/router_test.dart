import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelya_mobile/app/router/route_args.dart';
import 'package:panelya_mobile/app/router/router.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/core/config/auth_feature_config.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/account/domain/account_deletion_summary.dart';
import 'package:panelya_mobile/features/account/domain/account_provider.dart';
import 'package:panelya_mobile/features/account/domain/account_repository.dart';
import 'package:panelya_mobile/features/account/domain/account_session.dart';
import 'package:panelya_mobile/features/account/domain/blocked_account.dart';
import 'package:panelya_mobile/features/account/presentation/account_providers.dart';
import 'package:panelya_mobile/features/account/presentation/profile_screen.dart';
import 'package:panelya_mobile/features/account/presentation/security_screen.dart';
import 'package:panelya_mobile/features/account/presentation/blocked_accounts_screen.dart';
import 'package:panelya_mobile/features/account/presentation/delete_account_screen.dart';
import 'package:panelya_mobile/features/account/presentation/sessions_screen.dart';
import 'package:panelya_mobile/features/auth/domain/auth_repository.dart';
import 'package:panelya_mobile/features/auth/domain/auth_session_state.dart';
import 'package:panelya_mobile/features/auth/presentation/account_screen.dart';
import 'package:panelya_mobile/features/auth/presentation/auth_providers.dart';
import 'package:panelya_mobile/features/catalog/presentation/catalog_screen.dart';
import 'package:panelya_mobile/features/discover/domain/discover_repository.dart';
import 'package:panelya_mobile/features/discover/presentation/discover_providers.dart';
import 'package:panelya_mobile/features/discover/presentation/discover_screen.dart';
import 'package:panelya_mobile/features/discovery/domain/discovery_repository.dart';
import 'package:panelya_mobile/features/discovery/presentation/discovery_providers.dart';
import 'package:panelya_mobile/features/discovery/presentation/new_episodes_screen.dart';
import 'package:panelya_mobile/features/discovery/presentation/new_series_screen.dart';
import 'package:panelya_mobile/features/offline/domain/downloaded_episode.dart';
import 'package:panelya_mobile/features/offline/domain/offline_episode_content.dart';
import 'package:panelya_mobile/features/offline/domain/offline_episode_repository.dart';
import 'package:panelya_mobile/features/offline/presentation/downloads_screen.dart';
import 'package:panelya_mobile/features/offline/presentation/offline_providers.dart';
import 'package:panelya_mobile/features/push/domain/push_notification_repository.dart';
import 'package:panelya_mobile/features/push/presentation/notification_settings_screen.dart';
import 'package:panelya_mobile/features/push/presentation/push_providers.dart';
import 'package:panelya_mobile/features/reader/domain/reader_repository.dart';
import 'package:panelya_mobile/features/reader/presentation/reader_providers.dart';
import 'package:panelya_mobile/features/reader/presentation/reader_screen.dart';
import 'package:panelya_mobile/features/series/domain/series_repository.dart';
import 'package:panelya_mobile/features/series/presentation/series_providers.dart';
import 'package:panelya_mobile/features/series/presentation/series_screen.dart';

/// Gerçek ağ çağrısı yapmayan sahte repository'ler: bu testler router'ın
/// yönlendirme/güvenli-düşüş davranışını doğrular, ekranların veri
/// durumlarını değil (bunlar zaten kendi widget testlerinde kapsanıyor).
/// `Completer` kullanılır — hiç tamamlanmayan bir `Future` `Timer`
/// yaratmaz, bu yüzden `pumpAndSettle` asılı kalmaz.
class _NeverResolvingDiscoverRepository implements DiscoverRepository {
  @override
  Future<CatalogResponse> fetchCatalog() => Completer<CatalogResponse>().future;
}

class _NeverResolvingDiscoveryRepository implements DiscoveryRepository {
  @override
  Future<DiscoveryResponse> fetchDiscovery() =>
      Completer<DiscoveryResponse>().future;
}

class _NeverResolvingSeriesRepository implements SeriesRepository {
  @override
  Future<SeriesDetailResponse> fetchSeriesDetail(String slug) =>
      Completer<SeriesDetailResponse>().future;
}

class _NeverResolvingReaderRepository implements ReaderRepository {
  @override
  Future<EpisodeManifestResponse> fetchEpisodeManifest(
    String seriesSlug,
    String episodeSlug,
  ) => Completer<EpisodeManifestResponse>().future;
}

class _NeverResolvingOfflineEpisodeRepository
    implements OfflineEpisodeRepository {
  @override
  Future<bool> isDownloaded(String seriesSlug, String episodeSlug) =>
      Completer<bool>().future;

  @override
  Future<OfflineEpisodeContent?> loadDownloaded(
    String seriesSlug,
    String episodeSlug,
  ) => Completer<OfflineEpisodeContent?>().future;

  @override
  Stream<double> downloadEpisode({
    required String apiOrigin,
    required EpisodeManifestResponse manifest,
  }) => const Stream.empty();

  @override
  Future<void> deleteDownload(String seriesSlug, String episodeSlug) =>
      Completer<void>().future;

  @override
  Future<List<DownloadedEpisode>> listDownloaded() =>
      Completer<List<DownloadedEpisode>>().future;
}

class _NeverResolvingPushNotificationRepository
    implements PushNotificationRepository {
  @override
  Future<bool> requestPermission() => Completer<bool>().future;

  @override
  Future<bool> hasPermission() => Completer<bool>().future;

  @override
  Future<void> subscribeToNewEpisodes() => Completer<void>().future;

  @override
  Future<void> unsubscribeFromNewEpisodes() => Completer<void>().future;

  @override
  Stream<Uri> get notificationTaps => const Stream.empty();
}

/// `accountOverviewProvider`ı sonsuza kadar "yükleniyor" durumunda dondurmak
/// için (bkz. bu dosyanın "hiç tamamlanmayan Future" gerekçesi) — yalnız
/// `AccountHomeScreen`in gerçekten çağırdığı [fetchSignInProvider] anlamlı
/// bir şekilde uygulanır.
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
      throw UnimplementedError();

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

/// `features/account/` rotaları (bkz. ADR-047) yalnız kimliği doğrulanmış
/// durumda anlamlıdır (`accountOverviewProvider` -> `authSessionProvider`).
/// Sabit, senkron bir kimliği doğrulanmış durum döner — bu rotaların
/// SADECE doğru EKRANA çözüldüğünü doğrulamak için yeterlidir (ekranın
/// veri durumları kendi widget testlerinde kapsanıyor, bkz.
/// `test/features/account/presentation/`).
class _AuthenticatedFakeAuthRepository implements AuthRepository {
  static const _user = AuthUser(
    id: 'router-test-user',
    displayName: 'Router Test Kullanıcısı',
    email: 'router-test@panelya.invalid',
    emailVerified: true,
    role: 'reader',
  );

  @override
  AuthSessionState get currentState =>
      const AuthSessionState.authenticated(_user);

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

/// `NotificationPreferenceNotifier`in gerçek gövdesi `sharedPreferencesProvider`ı
/// okur (bkz. `push_providers.dart`); bu router testinde gereksiz bir
/// `SharedPreferences` mock kurulumundan kaçınmak için sahte bir sabit
/// değerle değiştirilir (aynı desen: diğer testler de düşük seviyeli
/// sistem sağlayıcılarını değil, özellik seviyesindeki provider'ı override
/// eder).
class _FakeNotificationPreferenceNotifier
    extends NotificationPreferenceNotifier {
  @override
  bool build() => true;
}

void main() {
  /// Gerçek `routerProvider` GoRouter'ını, üç ekranın da gerçek ağa
  /// çıkmadan (loading durumunda asılı kalarak) inşa edilebildiği bir
  /// `ProviderScope` içinde döndürür.
  ({GoRouter router, ProviderContainer container}) buildRouter({
    List<Override> extraOverrides = const [],
  }) {
    final container = ProviderContainer(
      overrides: [
        discoverRepositoryProvider.overrideWithValue(
          _NeverResolvingDiscoverRepository(),
        ),
        discoveryRepositoryProvider.overrideWithValue(
          _NeverResolvingDiscoveryRepository(),
        ),
        seriesRepositoryProvider.overrideWithValue(
          _NeverResolvingSeriesRepository(),
        ),
        readerRepositoryProvider.overrideWithValue(
          _NeverResolvingReaderRepository(),
        ),
        offlineEpisodeRepositoryProvider.overrideWithValue(
          _NeverResolvingOfflineEpisodeRepository(),
        ),
        pushNotificationRepositoryProvider.overrideWithValue(
          _NeverResolvingPushNotificationRepository(),
        ),
        notificationPreferenceProvider.overrideWith(
          _FakeNotificationPreferenceNotifier.new,
        ),
        ...extraOverrides,
      ],
    );
    addTearDown(container.dispose);
    return (router: container.read(routerProvider), container: container);
  }

  Future<void> pumpRouter(
    WidgetTester tester,
    GoRouter router,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    // `pumpAndSettle` asla kullanılmaz: hedef ekranlar sahte repository'ler
    // yüzünden hep "yükleniyor" durumunda kalır ve `CircularProgressIndicator`
    // sonsuz döngülü bir animasyon çalıştırır — `pumpAndSettle` bu yüzden
    // asla ayarlanamaz (timeout). Sabit sayıda frame yeterli.
    await tester.pump();
    await tester.pump();
  }

  group('safe fallback (PLAN Görev 3: bilinmeyen/bozuk link -> keşif)', () {
    testWidgets('an unmatched path falls back to the discover screen via errorBuilder', (
      tester,
    ) async {
      final built = buildRouter();
      await pumpRouter(tester, built.router, built.container);

      built.router.go('/this/path/does/not/exist');
      await tester.pump();
      await tester.pump();

      // `go()` bir önceki (geçerli) konumu yığından tam olarak
      // temizlemeyebilir (bkz. go_router'ın hata sayfası davranışı); önemli
      // olan en az bir çalışan `DiscoverScreen`'in görünmesi ve crash
      // olmamasıdır — boş/kırık bir "not found" sayfası değil.
      expect(find.byType(DiscoverScreen), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a malformed custom-scheme link falls back to discover via redirect', (
      tester,
    ) async {
      final built = buildRouter();
      await pumpRouter(tester, built.router, built.container);

      built.router.go('panelya://series');
      await tester.pump();
      await tester.pump();

      expect(find.byType(DiscoverScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('panelya:// custom scheme redirect', () {
    testWidgets('bare scheme root navigates to discover', (tester) async {
      final built = buildRouter();
      await pumpRouter(tester, built.router, built.container);

      built.router.go('panelya://');
      await tester.pump();
      await tester.pump();

      expect(find.byType(DiscoverScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('series deep link navigates to the series screen', (
      tester,
    ) async {
      final built = buildRouter();
      await pumpRouter(tester, built.router, built.container);

      built.router.go('panelya://series/gece-vardiyasi');
      await tester.pump();
      await tester.pump();

      expect(find.byType(SeriesScreen), findsOneWidget);
      final screen = tester.widget<SeriesScreen>(find.byType(SeriesScreen));
      expect(screen.slug, 'gece-vardiyasi');
      expect(tester.takeException(), isNull);
    });

    testWidgets('episode deep link navigates to the reader screen', (
      tester,
    ) async {
      final built = buildRouter();
      await pumpRouter(tester, built.router, built.container);

      built.router.go('panelya://series/gece-vardiyasi/read/bolum-1');
      await tester.pump();
      await tester.pump();

      expect(find.byType(ReaderScreen), findsOneWidget);
      final screen = tester.widget<ReaderScreen>(find.byType(ReaderScreen));
      expect(screen.seriesSlug, 'gece-vardiyasi');
      expect(screen.episodeSlug, 'bolum-1');
      expect(tester.takeException(), isNull);
    });
  });

  group(
    'editorial keşif ayrımı — /catalog, /new-series, /new-episodes (PLAN Görev 2)',
    () {
      testWidgets('"/catalog" resolves to CatalogScreen without a preselected genre', (
        tester,
      ) async {
        final built = buildRouter();
        await pumpRouter(tester, built.router, built.container);

        built.router.go('/catalog');
        await tester.pump();
        await tester.pump();

        expect(find.byType(CatalogScreen), findsOneWidget);
        final screen = tester.widget<CatalogScreen>(find.byType(CatalogScreen));
        expect(screen.initialGenre, isNull);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        '"/catalog" with a CatalogRouteArgs extra carries the initial genre '
        'through to CatalogScreen',
        (tester) async {
          final built = buildRouter();
          await pumpRouter(tester, built.router, built.container);

          built.router.go(
            '/catalog',
            extra: const CatalogRouteArgs(initialGenre: 'Gizem'),
          );
          await tester.pump();
          await tester.pump();

          expect(find.byType(CatalogScreen), findsOneWidget);
          final screen = tester.widget<CatalogScreen>(
            find.byType(CatalogScreen),
          );
          expect(screen.initialGenre, 'Gizem');
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'an unexpected `extra` type on /catalog is ignored, not crashed on',
        (tester) async {
          final built = buildRouter();
          await pumpRouter(tester, built.router, built.container);

          built.router.go('/catalog', extra: 'not-a-CatalogRouteArgs');
          await tester.pump();
          await tester.pump();

          expect(find.byType(CatalogScreen), findsOneWidget);
          final screen = tester.widget<CatalogScreen>(
            find.byType(CatalogScreen),
          );
          expect(screen.initialGenre, isNull);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('"/new-series" resolves to NewSeriesScreen', (tester) async {
        final built = buildRouter();
        await pumpRouter(tester, built.router, built.container);

        built.router.go('/new-series');
        await tester.pump();
        await tester.pump();

        expect(find.byType(NewSeriesScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('"/new-episodes" resolves to NewEpisodesScreen', (
        tester,
      ) async {
        final built = buildRouter();
        await pumpRouter(tester, built.router, built.container);

        built.router.go('/new-episodes');
        await tester.pump();
        await tester.pump();

        expect(find.byType(NewEpisodesScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        '"/downloads" resolves to DownloadsScreen (mobile-only, bkz. '
        'docs/local-gap-backlog.md P2 madde 3)',
        (tester) async {
          final built = buildRouter();
          await pumpRouter(tester, built.router, built.container);

          built.router.go('/downloads');
          await tester.pump();
          await tester.pump();

          expect(find.byType(DownloadsScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '"/account" resolves to AccountScreen (mobile-only, yalnız '
        'AuthFeatureConfig.enabled açıkken discover_screen.dart\'taki giriş '
        'noktasından erişilir)',
        (tester) async {
          final built = buildRouter();
          await pumpRouter(tester, built.router, built.container);

          built.router.go('/account');
          await tester.pump();
          await tester.pump();

          expect(find.byType(AccountScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '"/account/profile" resolves to ProfileScreen (mobile-only, bkz. '
        'ADR-047 — yalnız AccountHomeScreen\'in gezinme satırından '
        'erişilir)',
        (tester) async {
          final built = buildRouter(
            extraOverrides: [
              authFeatureConfigProvider.overrideWithValue(
                const AuthFeatureConfig(enabled: true),
              ),
              authRepositoryProvider.overrideWithValue(
                _AuthenticatedFakeAuthRepository(),
              ),
              accountRepositoryProvider.overrideWithValue(
                _NeverResolvingAccountRepository(),
              ),
            ],
          );
          await pumpRouter(tester, built.router, built.container);

          built.router.go('/account/profile');
          await tester.pump();
          await tester.pump();

          expect(find.byType(ProfileScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '"/account/security" resolves to SecurityScreen (mobile-only, bkz. '
        'ADR-047 — yalnız AccountHomeScreen\'in gezinme satırından '
        'erişilir)',
        (tester) async {
          final built = buildRouter(
            extraOverrides: [
              authFeatureConfigProvider.overrideWithValue(
                const AuthFeatureConfig(enabled: true),
              ),
              authRepositoryProvider.overrideWithValue(
                _AuthenticatedFakeAuthRepository(),
              ),
              accountRepositoryProvider.overrideWithValue(
                _NeverResolvingAccountRepository(),
              ),
            ],
          );
          await pumpRouter(tester, built.router, built.container);

          built.router.go('/account/security');
          await tester.pump();
          await tester.pump();

          expect(find.byType(SecurityScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '"/account/sessions" resolves to SessionsScreen (mobile-only, bkz. '
        'ADR-047 — yalnız AccountHomeScreen\'in gezinme satırından '
        'erişilir)',
        (tester) async {
          final built = buildRouter(
            extraOverrides: [
              authFeatureConfigProvider.overrideWithValue(
                const AuthFeatureConfig(enabled: true),
              ),
              authRepositoryProvider.overrideWithValue(
                _AuthenticatedFakeAuthRepository(),
              ),
              accountRepositoryProvider.overrideWithValue(
                _NeverResolvingAccountRepository(),
              ),
            ],
          );
          await pumpRouter(tester, built.router, built.container);

          built.router.go('/account/sessions');
          await tester.pump();
          await tester.pump();

          expect(find.byType(SessionsScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '"/account/blocked" resolves to BlockedAccountsScreen (mobile-only, '
        'bkz. ADR-047 — yalnız AccountHomeScreen\'in gezinme satırından '
        'erişilir)',
        (tester) async {
          final built = buildRouter(
            extraOverrides: [
              authFeatureConfigProvider.overrideWithValue(
                const AuthFeatureConfig(enabled: true),
              ),
              authRepositoryProvider.overrideWithValue(
                _AuthenticatedFakeAuthRepository(),
              ),
              accountRepositoryProvider.overrideWithValue(
                _NeverResolvingAccountRepository(),
              ),
            ],
          );
          await pumpRouter(tester, built.router, built.container);

          built.router.go('/account/blocked');
          await tester.pump();
          await tester.pump();

          expect(find.byType(BlockedAccountsScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '"/account/delete" resolves to DeleteAccountScreen (mobile-only, '
        'bkz. ADR-047 — yalnız AccountHomeScreen\'in gezinme satırından '
        'erişilir)',
        (tester) async {
          final built = buildRouter(
            extraOverrides: [
              authFeatureConfigProvider.overrideWithValue(
                const AuthFeatureConfig(enabled: true),
              ),
              authRepositoryProvider.overrideWithValue(
                _AuthenticatedFakeAuthRepository(),
              ),
              accountRepositoryProvider.overrideWithValue(
                _NeverResolvingAccountRepository(),
              ),
            ],
          );
          await pumpRouter(tester, built.router, built.container);

          built.router.go('/account/delete');
          await tester.pump();
          await tester.pump();

          expect(find.byType(DeleteAccountScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '"/notifications" resolves to NotificationSettingsScreen '
        '(mobile-only, hesap gerektirmez, her zaman erişilebilir)',
        (tester) async {
          final built = buildRouter();
          await pumpRouter(tester, built.router, built.container);

          built.router.go('/notifications');
          await tester.pump();
          await tester.pump();

          expect(find.byType(NotificationSettingsScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    },
  );
}
