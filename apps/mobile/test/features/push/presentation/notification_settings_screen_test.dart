import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/core/storage/shared_preferences_provider.dart';
import 'package:panelya_mobile/features/push/domain/push_notification_repository.dart';
import 'package:panelya_mobile/features/push/presentation/notification_settings_screen.dart';
import 'package:panelya_mobile/features/push/presentation/push_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bu dosyanın amacı: `NotificationSettingsScreen`nin anahtarı GERÇEK OS
/// izin durumuyla (bkz. `pushPermissionStatusProvider`) ve cihaz-yerel
/// tercihle (bkz. `notificationPreferenceProvider`) doğru birleştirdiğini
/// (`effectiveEnabled = hasPermission && preference`) ve aç/kapa
/// aksiyonlarının doğru repository çağrılarını yaptığını doğrulamak.
class _FakePushNotificationRepository implements PushNotificationRepository {
  _FakePushNotificationRepository({
    this.permissionGranted = true,
    this.requestPermissionResult = true,
  });

  bool permissionGranted;
  bool requestPermissionResult;
  final List<String> calls = [];

  @override
  Future<bool> requestPermission() async {
    calls.add('requestPermission');
    if (requestPermissionResult) permissionGranted = true;
    return requestPermissionResult;
  }

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<void> subscribeToNewEpisodes() async {
    calls.add('subscribe');
  }

  @override
  Future<void> unsubscribeFromNewEpisodes() async {
    calls.add('unsubscribe');
  }

  @override
  Stream<Uri> get notificationTaps => const Stream.empty();
}

Future<Widget> _wrap(
  _FakePushNotificationRepository repository, {
  bool initialPreference = true,
}) async {
  SharedPreferences.setMockInitialValues({
    notifyNewEpisodesPreferenceKey: initialPreference,
  });
  final sharedPreferences = await SharedPreferences.getInstance();

  final router = GoRouter(
    initialLocation: '/notifications',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      pushNotificationRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
  );
}

void main() {
  testWidgets(
    'izin verilmiş ve tercih açıkken anahtar açık görünür',
    (tester) async {
      final repository = _FakePushNotificationRepository();
      await tester.pumpWidget(await _wrap(repository));
      await tester.pumpAndSettle();

      final tile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(tile.value, isTrue);
    },
  );

  testWidgets(
    'izin verilmiş ama tercih kapalıyken anahtar kapalı görünür',
    (tester) async {
      final repository = _FakePushNotificationRepository();
      await tester.pumpWidget(
        await _wrap(repository, initialPreference: false),
      );
      await tester.pumpAndSettle();

      final tile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(tile.value, isFalse);
    },
  );

  testWidgets(
    'OS izni kapalıyken (kullanıcı ayarlardan geri almış) tercih açık '
    'olsa bile anahtar dürüstçe kapalı görünür',
    (tester) async {
      final repository = _FakePushNotificationRepository(
        permissionGranted: false,
      );
      await tester.pumpWidget(await _wrap(repository));
      await tester.pumpAndSettle();

      final tile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(tile.value, isFalse);
      expect(find.textContaining('izni kapalı'), findsOneWidget);
    },
  );

  testWidgets(
    'anahtarı açmak izin isteyip kabul edilirse abone eder ve tercihi '
    'kaydeder',
    (tester) async {
      final repository = _FakePushNotificationRepository(
        permissionGranted: false,
        requestPermissionResult: true,
      );
      await tester.pumpWidget(
        await _wrap(repository, initialPreference: false),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(repository.calls, ['requestPermission', 'subscribe']);
      final tile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(tile.value, isTrue);
    },
  );

  testWidgets(
    'anahtarı açmaya çalışıp izin reddedilirse abone olunmaz, anahtar '
    'kapalı kalır',
    (tester) async {
      final repository = _FakePushNotificationRepository(
        permissionGranted: false,
        requestPermissionResult: false,
      );
      await tester.pumpWidget(
        await _wrap(repository, initialPreference: false),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(repository.calls, ['requestPermission']);
      final tile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(tile.value, isFalse);
    },
  );

  testWidgets(
    'anahtarı kapatmak aboneliği kaldırır ve tercihi kaydeder',
    (tester) async {
      final repository = _FakePushNotificationRepository();
      await tester.pumpWidget(await _wrap(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(repository.calls, ['unsubscribe']);
      final tile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(tile.value, isFalse);
    },
  );

  testWidgets(
    'the app bar offers a home button that navigates to "/" and meets the '
    '44x44 touch target minimum',
    (tester) async {
      final repository = _FakePushNotificationRepository();
      await tester.pumpWidget(await _wrap(repository));
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
