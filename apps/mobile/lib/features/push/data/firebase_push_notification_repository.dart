import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../domain/push_notification_repository.dart';
import 'apns_token_wait.dart';
import 'notification_tap_stream.dart';
import 'push_authorization.dart';

/// Firebase `apns-token-not-set` hata kodu. iOS'a özgüdür; Android'de bu
/// kod hiç üretilmez. Platform dallanması (`Platform.isIOS`) yerine HATA
/// KODU üzerinden ele alıyoruz — Android'de `getAPNSToken()` her zaman
/// `null` döndüğü için token beklemek Android'i yanlışlıkla bloklardı.
const _apnsTokenNotSetCode = 'apns-token-not-set';

class FirebasePushNotificationRepository
    implements PushNotificationRepository {
  FirebasePushNotificationRepository(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return isAuthorizedStatus(settings.authorizationStatus);
  }

  @override
  Future<bool> hasPermission() async {
    final settings = await _messaging.getNotificationSettings();
    return isAuthorizedStatus(settings.authorizationStatus);
  }

  /// iOS'ta APNs token'ı hazır değilken hem `subscribeToTopic` hem
  /// `unsubscribeFromTopic` [_apnsTokenNotSetCode] fırlatır. Token'ı
  /// sınırlı süre bekleyip BİR KEZ daha deneriz; token hiç gelmezse
  /// (ör. simulator) [PushSubscriptionUnavailableException] fırlatılır.
  /// Gerçek retry/bekleme mantığı [withApnsRetry]'da yaşar (bkz. o
  /// fonksiyonun doc yorumu) — Firebase eklenti sınırına dokunmadan test
  /// edilebilsin diye buradan yalnız hata-kodu tahmin edicisi ve token
  /// bekleyicisi enjekte edilir.
  ///
  /// Abonelik KALDIRMA da sessizce başarılı sayılmaz: cihaz önceki bir
  /// açılışta abone olmuş olabilir, "kaldırıldı" demek yanlış olurdu.
  Future<void> _withApnsRetry(Future<void> Function() action) => withApnsRetry(
    action: action,
    isApnsTokenNotSetError: (error) =>
        error is FirebaseException && error.code == _apnsTokenNotSetCode,
    waitForToken: () => waitForApnsToken(getToken: _messaging.getAPNSToken),
  );

  @override
  Future<void> subscribeToNewEpisodes() =>
      _withApnsRetry(() => _messaging.subscribeToTopic(newEpisodesPushTopic));

  @override
  Future<void> unsubscribeFromNewEpisodes() => _withApnsRetry(
    () => _messaging.unsubscribeFromTopic(newEpisodesPushTopic),
  );

  /// Birleştirme mantığı (soğuk başlangıçta bekleyen bildirim + arka plan
  /// dokunmaları) [notificationTapStream]'de yaşar — Firebase'in statik
  /// `onMessageOpenedApp` akışına dokunmadan test edilebilsin diye buradan
  /// yalnız enjekte edilir (bkz. o fonksiyonun doc yorumu).
  @override
  Stream<Uri> get notificationTaps => notificationTapStream(
    getInitialMessage: _messaging.getInitialMessage,
    onMessageOpenedApp: FirebaseMessaging.onMessageOpenedApp,
  );
}
