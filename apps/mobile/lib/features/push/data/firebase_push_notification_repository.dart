import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../domain/push_exceptions.dart';
import '../domain/push_notification_repository.dart';
import 'apns_token_wait.dart';

/// Firebase `apns-token-not-set` hata kodu. iOS'a özgüdür; Android'de bu
/// kod hiç üretilmez. Platform dallanması (`Platform.isIOS`) yerine HATA
/// KODU üzerinden ele alıyoruz — Android'de `getAPNSToken()` her zaman
/// `null` döndüğü için token beklemek Android'i yanlışlıkla bloklardı.
const _apnsTokenNotSetCode = 'apns-token-not-set';

class FirebasePushNotificationRepository
    implements PushNotificationRepository {
  FirebasePushNotificationRepository(this._messaging);

  final FirebaseMessaging _messaging;

  bool _isAuthorized(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return _isAuthorized(settings.authorizationStatus);
  }

  @override
  Future<bool> hasPermission() async {
    final settings = await _messaging.getNotificationSettings();
    return _isAuthorized(settings.authorizationStatus);
  }

  /// iOS'ta APNs token'ı hazır değilken hem `subscribeToTopic` hem
  /// `unsubscribeFromTopic` [_apnsTokenNotSetCode] fırlatır. Token'ı
  /// sınırlı süre bekleyip BİR KEZ daha deneriz; token hiç gelmezse
  /// (ör. simulator) [PushSubscriptionUnavailableException] fırlatılır.
  ///
  /// Abonelik KALDIRMA da sessizce başarılı sayılmaz: cihaz önceki bir
  /// açılışta abone olmuş olabilir, "kaldırıldı" demek yanlış olurdu.
  Future<void> _withApnsRetry(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseException catch (error) {
      if (error.code != _apnsTokenNotSetCode) rethrow;

      final ready = await waitForApnsToken(getToken: _messaging.getAPNSToken);
      if (!ready) throw const PushSubscriptionUnavailableException();

      try {
        await action();
      } on FirebaseException catch (retryError) {
        if (retryError.code != _apnsTokenNotSetCode) rethrow;
        throw const PushSubscriptionUnavailableException();
      }
    }
  }

  @override
  Future<void> subscribeToNewEpisodes() =>
      _withApnsRetry(() => _messaging.subscribeToTopic(newEpisodesPushTopic));

  @override
  Future<void> unsubscribeFromNewEpisodes() => _withApnsRetry(
    () => _messaging.unsubscribeFromTopic(newEpisodesPushTopic),
  );

  @override
  Stream<Uri> get notificationTaps async* {
    final initial = await _messaging.getInitialMessage();
    final initialUri = initial == null ? null : _deepLink(initial);
    if (initialUri != null) yield initialUri;

    yield* FirebaseMessaging.onMessageOpenedApp
        .map(_deepLink)
        .where((uri) => uri != null)
        .cast<Uri>();
  }

  Uri? _deepLink(RemoteMessage message) {
    final raw = message.data[deepLinkDataKey];
    if (raw == null) return null;
    return Uri.tryParse(raw);
  }
}
