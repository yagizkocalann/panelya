import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/features/push/data/push_deep_link.dart';
import 'package:panelya_mobile/features/push/domain/push_notification_repository.dart';

void main() {
  group('resolveDeepLink', () {
    test('gecerli deepLink verisi dogru Uri\'ye cozulur', () {
      final message = RemoteMessage(
        data: {deepLinkDataKey: 'panelya://series/a/read/b'},
      );

      expect(
        resolveDeepLink(message),
        Uri.parse('panelya://series/a/read/b'),
      );
    });

    test('deepLink anahtari EKSIKSE null doner, hata firlatmaz', () {
      final message = RemoteMessage(data: const {'baska-alan': 'deger'});

      expect(resolveDeepLink(message), isNull);
    });

    test('data yuku BOSSA null doner', () {
      const message = RemoteMessage();

      expect(resolveDeepLink(message), isNull);
    });

    test('deepLink degeri GECERSIZ bir URI ise null doner', () {
      // Uri.tryParse bosluk/kontrol karakteri gibi cogu "kaba" girdiyi
      // yuzde-kodlayarak sessizce kabul eder; kesin null ureten gecerli
      // bir ornek, kapatilmamis bir IPv6 host parantezidir (RFC 3986'ya
      // gore parse edilemez).
      final message = RemoteMessage(
        data: const {deepLinkDataKey: 'http://[invalid'},
      );

      expect(resolveDeepLink(message), isNull);
    });
  });
}
