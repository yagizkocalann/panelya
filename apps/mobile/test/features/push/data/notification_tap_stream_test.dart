import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/features/push/data/notification_tap_stream.dart';
import 'package:panelya_mobile/features/push/domain/push_notification_repository.dart';

/// `FirebasePushNotificationRepository.notificationTaps`nin birlestirme
/// mantigini (soguk baslangicta bekleyen bildirim + arka plan dokunmalari)
/// Firebase kurulumu OLMADAN test eder. Onceden bu mantik hic dogrudan
/// test edilmiyordu — yalniz `DeferredPushNotificationRepository`nin genel
/// gecikmeli-devretme davranisi test ediliyordu, bu birlestirmenin
/// KENDISI degil.
void main() {
  group('notificationTapStream', () {
    test(
      'soguk baslangicta bekleyen bildirim varsa deep-linki ILK once '
      'yayinlanir, KAYBOLMAZ',
      () async {
        final initial = RemoteMessage(
          data: const {deepLinkDataKey: 'panelya://series/a/read/b'},
        );

        final stream = notificationTapStream(
          getInitialMessage: () async => initial,
          onMessageOpenedApp: const Stream<RemoteMessage>.empty(),
        );

        final events = await stream.toList();

        expect(events, [Uri.parse('panelya://series/a/read/b')]);
      },
    );

    test(
      'soguk baslangicta bekleyen bildirim YOKSA (getInitialMessage null '
      'doner) hicbir sey yayinlanmaz, sonraki akis devam eder',
      () async {
        final tapped = RemoteMessage(
          data: const {deepLinkDataKey: 'panelya://series/x/read/y'},
        );
        final controller = StreamController<RemoteMessage>();
        addTearDown(controller.close);

        final events = <Uri>[];
        final sub = notificationTapStream(
          getInitialMessage: () async => null,
          onMessageOpenedApp: controller.stream,
        ).listen(events.add);
        addTearDown(sub.cancel);

        await Future<void>.delayed(Duration.zero);
        expect(events, isEmpty);

        controller.add(tapped);
        await Future<void>.delayed(Duration.zero);

        expect(events, [Uri.parse('panelya://series/x/read/y')]);
      },
    );

    test(
      'arka planda dokunulan BIRDEN FAZLA bildirim sirayla yayinlanir',
      () async {
        final first = RemoteMessage(
          data: const {deepLinkDataKey: 'panelya://series/a/read/1'},
        );
        final second = RemoteMessage(
          data: const {deepLinkDataKey: 'panelya://series/a/read/2'},
        );

        final stream = notificationTapStream(
          getInitialMessage: () async => null,
          onMessageOpenedApp: Stream.fromIterable([first, second]),
        );

        final events = await stream.toList();

        expect(events, [
          Uri.parse('panelya://series/a/read/1'),
          Uri.parse('panelya://series/a/read/2'),
        ]);
      },
    );

    test(
      'deep-linki cozulemeyen mesajlar SESSIZCE atlanir — akisi bozmaz',
      () async {
        final noDeepLink = RemoteMessage(data: const {'baska': 'veri'});
        final valid = RemoteMessage(
          data: const {deepLinkDataKey: 'panelya://series/a/read/b'},
        );

        final stream = notificationTapStream(
          getInitialMessage: () async => null,
          onMessageOpenedApp: Stream.fromIterable([noDeepLink, valid]),
        );

        final events = await stream.toList();

        expect(events, [Uri.parse('panelya://series/a/read/b')]);
      },
    );

    test(
      'soguk baslangic mesaji deep-linksizse (ör. baska amacli bir '
      'bildirim) atlanir ama sonraki akis KAYBOLMAZ',
      () async {
        final initialNoDeepLink = RemoteMessage(data: const {'baska': 'x'});
        final tapped = RemoteMessage(
          data: const {deepLinkDataKey: 'panelya://series/a/read/b'},
        );

        final stream = notificationTapStream(
          getInitialMessage: () async => initialNoDeepLink,
          onMessageOpenedApp: Stream.fromIterable([tapped]),
        );

        final events = await stream.toList();

        expect(events, [Uri.parse('panelya://series/a/read/b')]);
      },
    );
  });
}
