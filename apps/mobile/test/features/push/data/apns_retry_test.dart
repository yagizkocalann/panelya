import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/features/push/data/apns_token_wait.dart';
import 'package:panelya_mobile/features/push/domain/push_exceptions.dart';

/// Bu dosya `FirebasePushNotificationRepository._withApnsRetry`nin gerçek
/// mantığını taşıyan [withApnsRetry]'ı, Firebase eklentisine hiç
/// dokunmadan test eder (bkz. `apns_token_wait.dart` doc yorumu). Amaç,
/// önceden HİÇ otomatik testi olmayan üç canlı QA senaryosunu kapsamak:
/// token GEÇ gelirse abonelik yine olur mu, token HİÇ gelmezse durum
/// dürüstçe raporlanıyor mu, ve APNs dışı bir hata yanlışlıkla
/// yutulmuyor/sarılmıyor mu.
bool _isApnsTokenNotSet(Object error) =>
    error is FirebaseException && error.code == 'apns-token-not-set';

FirebaseException _apnsTokenNotSet() =>
    FirebaseException(plugin: 'firebase_messaging', code: 'apns-token-not-set');

void main() {
  group('withApnsRetry', () {
    test('ilk deneme basarili olursa BEKLEMEDEN doner', () async {
      var actionCalls = 0;
      var waitCalls = 0;

      await withApnsRetry(
        action: () async {
          actionCalls++;
        },
        isApnsTokenNotSetError: _isApnsTokenNotSet,
        waitForToken: () async {
          waitCalls++;
          return true;
        },
      );

      expect(actionCalls, 1);
      expect(waitCalls, 0, reason: 'ilk deneme basariliysa bekleme gereksiz');
    });

    test(
      'token GEC gelirse (waitForToken true doner) yeniden deneme '
      'basarili olur — abonelik GERCEKTEN gerceklesir',
      () async {
        var actionCalls = 0;

        await withApnsRetry(
          action: () async {
            actionCalls++;
            // Ilk cagri APNs token'i henuz hazir olmadigi icin basarisiz;
            // ikinci cagri (retry) basarili.
            if (actionCalls == 1) throw _apnsTokenNotSet();
          },
          isApnsTokenNotSetError: _isApnsTokenNotSet,
          waitForToken: () async => true,
        );

        expect(
          actionCalls,
          2,
          reason: 'bir ilk deneme + bir retry cagrisi olmali',
        );
      },
    );

    test(
      'token HIC gelmezse (waitForToken false doner) durum DURUSTCE '
      'raporlanir — sahte basari uretilmez, retry hic denenmez',
      () async {
        var actionCalls = 0;

        await expectLater(
          withApnsRetry(
            action: () async {
              actionCalls++;
              throw _apnsTokenNotSet();
            },
            isApnsTokenNotSetError: _isApnsTokenNotSet,
            waitForToken: () async => false,
          ),
          throwsA(isA<PushSubscriptionUnavailableException>()),
        );

        expect(
          actionCalls,
          1,
          reason: 'token hic gelmediyse retry denenmemeli',
        );
      },
    );

    test(
      'token bekledikten SONRA retry de ayni hatayi verirse (cift '
      'basarisizlik) yine DURUSTCE raporlanir',
      () async {
        var actionCalls = 0;

        await expectLater(
          withApnsRetry(
            action: () async {
              actionCalls++;
              throw _apnsTokenNotSet();
            },
            isApnsTokenNotSetError: _isApnsTokenNotSet,
            waitForToken: () async => true,
          ),
          throwsA(isA<PushSubscriptionUnavailableException>()),
        );

        expect(actionCalls, 2, reason: 'ilk deneme + bir retry yapilmali');
      },
    );

    test(
      'APNs disi bir hata OLDUGU GIBI yeniden firlatilir, sarilmaz ve '
      'bekleme hic denenmez',
      () async {
        var waitCalls = 0;

        await expectLater(
          withApnsRetry(
            action: () async => throw StateError('baska bir hata'),
            isApnsTokenNotSetError: _isApnsTokenNotSet,
            waitForToken: () async {
              waitCalls++;
              return true;
            },
          ),
          throwsA(isA<StateError>()),
        );

        expect(waitCalls, 0);
      },
    );

    test(
      'retry sirasinda APNs disi FARKLI bir hata gelirse OLDUGU GIBI '
      'yeniden firlatilir — PushSubscriptionUnavailableException\'a '
      'SARILMAZ',
      () async {
        var actionCalls = 0;

        await expectLater(
          withApnsRetry(
            action: () async {
              actionCalls++;
              if (actionCalls == 1) throw _apnsTokenNotSet();
              throw StateError('retry sirasinda baska bir hata');
            },
            isApnsTokenNotSetError: _isApnsTokenNotSet,
            waitForToken: () async => true,
          ),
          throwsA(isA<StateError>()),
        );

        expect(actionCalls, 2);
      },
    );
  });
}
