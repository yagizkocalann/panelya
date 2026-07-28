import 'package:firebase_messaging/firebase_messaging.dart';

import '../domain/push_notification_repository.dart';

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

  @override
  Future<void> subscribeToNewEpisodes() =>
      _messaging.subscribeToTopic(newEpisodesPushTopic);

  @override
  Future<void> unsubscribeFromNewEpisodes() =>
      _messaging.unsubscribeFromTopic(newEpisodesPushTopic);

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
