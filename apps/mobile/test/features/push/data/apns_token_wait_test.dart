import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/features/push/data/apns_token_wait.dart';

void main() {
  group('waitForApnsToken', () {
    test('token ilk denemede hazirsa HIC beklemeden true doner', () async {
      var calls = 0;
      var slept = 0;

      final ready = await waitForApnsToken(
        getToken: () async {
          calls++;
          return 'apns-token';
        },
        delay: (_) async => slept++,
      );

      expect(ready, isTrue);
      expect(calls, 1);
      expect(slept, 0, reason: 'hazir tokenda gecikme yasanmamali');
    });

    test('token birkac denemeden SONRA gelirse true doner', () async {
      var calls = 0;

      final ready = await waitForApnsToken(
        getToken: () async {
          calls++;
          // Ilk iki yoklamada APNs kaydi henuz tamamlanmamis.
          return calls < 3 ? null : 'apns-token';
        },
        delay: (_) async {},
      );

      expect(ready, isTrue);
      expect(calls, 3);
    });

    test(
      'token hic gelmezse SONSUZA KADAR beklemez, deneme sayisinda durur',
      () async {
        var calls = 0;
        var slept = 0;

        final ready = await waitForApnsToken(
          getToken: () async {
            calls++;
            return null;
          },
          attempts: 4,
          delay: (_) async => slept++,
        );

        expect(ready, isFalse);
        expect(calls, 4);
        // Son denemeden sonra beklemek anlamsiz: 4 deneme -> 3 bekleme.
        expect(slept, 3);
      },
    );

    test('BOS string token "hazir" sayilmaz', () async {
      final ready = await waitForApnsToken(
        getToken: () async => '',
        attempts: 2,
        delay: (_) async {},
      );

      expect(ready, isFalse);
    });

    test('beklemeler yapilandirilan araligi kullanir', () async {
      final waits = <Duration>[];

      await waitForApnsToken(
        getToken: () async => null,
        attempts: 3,
        interval: const Duration(milliseconds: 40),
        delay: (duration) async => waits.add(duration),
      );

      expect(waits, [
        const Duration(milliseconds: 40),
        const Duration(milliseconds: 40),
      ]);
    });
  });
}
