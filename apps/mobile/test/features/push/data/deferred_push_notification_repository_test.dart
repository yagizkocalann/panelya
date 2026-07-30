import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/features/push/data/deferred_push_notification_repository.dart';
import 'package:panelya_mobile/features/push/domain/push_notification_repository.dart';

class _RecordingRepository implements PushNotificationRepository {
  final List<String> calls = [];
  final StreamController<Uri> taps = StreamController<Uri>.broadcast();
  bool permissionResult = true;

  @override
  Future<bool> requestPermission() async {
    calls.add('requestPermission');
    return permissionResult;
  }

  @override
  Future<bool> hasPermission() async {
    calls.add('hasPermission');
    return permissionResult;
  }

  @override
  Future<void> subscribeToNewEpisodes() async => calls.add('subscribe');

  @override
  Future<void> unsubscribeFromNewEpisodes() async => calls.add('unsubscribe');

  @override
  Stream<Uri> get notificationTaps => taps.stream;
}

void main() {
  group('DeferredPushNotificationRepository', () {
    test(
      'gercek repository HAZIR OLMADAN gelen cagri BEKLER, kaybolmaz',
      () async {
        final inner = _RecordingRepository();
        final completer = Completer<PushNotificationRepository>();
        final repository = DeferredPushNotificationRepository(completer.future);

        // Firebase henuz baslatilmadi: cagri simdi yapiliyor.
        final pending = repository.requestPermission();
        await Future<void>.delayed(Duration.zero);
        expect(inner.calls, isEmpty, reason: 'henuz devredilmemeli');

        // Baslatma tamamlandi.
        completer.complete(inner);

        expect(await pending, isTrue);
        expect(inner.calls, ['requestPermission']);
      },
    );

    test('hazir olduktan sonra cagrilar dogrudan devredilir', () async {
      final inner = _RecordingRepository();
      final repository = DeferredPushNotificationRepository(
        Future.value(inner),
      );

      await repository.hasPermission();
      await repository.subscribeToNewEpisodes();
      await repository.unsubscribeFromNewEpisodes();

      expect(inner.calls, ['hasPermission', 'subscribe', 'unsubscribe']);
    });

    test('gercek repository\'nin firlattigi hata OLDUGU GIBI gecer', () async {
      final repository = DeferredPushNotificationRepository(
        Future.value(_ThrowingRepository()),
      );

      await expectLater(
        repository.subscribeToNewEpisodes(),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'baslatma basarisiz olursa hata YUTULMAZ — sahte basari uretilmez',
      () async {
        final repository = DeferredPushNotificationRepository(
          Future<PushNotificationRepository>.error(
            StateError('Firebase baslatilamadi'),
          ),
        );

        await expectLater(
          repository.requestPermission(),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('bildirime dokunma akisi da beklemeye tabidir — soguk baslangicta '
        'bekleyen bildirim KAYBOLMAZ', () async {
      final inner = _RecordingRepository();
      addTearDown(inner.taps.close);
      final completer = Completer<PushNotificationRepository>();
      final repository = DeferredPushNotificationRepository(completer.future);

      final received = <Uri>[];
      final sub = repository.notificationTaps.listen(received.add);
      addTearDown(sub.cancel);

      // Hazir olmadan once dinlemeye baslandi.
      await Future<void>.delayed(Duration.zero);
      completer.complete(inner);
      await Future<void>.delayed(Duration.zero);

      inner.taps.add(Uri.parse('panelya://series/a/read/b'));
      await Future<void>.delayed(Duration.zero);

      expect(received, [Uri.parse('panelya://series/a/read/b')]);
    });
  });
}

class _ThrowingRepository implements PushNotificationRepository {
  @override
  Future<bool> requestPermission() async => throw StateError('hata');

  @override
  Future<bool> hasPermission() async => throw StateError('hata');

  @override
  Future<void> subscribeToNewEpisodes() async => throw StateError('hata');

  @override
  Future<void> unsubscribeFromNewEpisodes() async => throw StateError('hata');

  @override
  Stream<Uri> get notificationTaps => const Stream.empty();
}
