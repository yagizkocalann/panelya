import 'package:firebase_messaging/firebase_messaging.dart';

import '../domain/push_notification_repository.dart';

class FirebasePushNotificationRepository
    implements PushNotificationRepository {
  FirebasePushNotificationRepository(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<void> requestPermission() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  @override
  Future<String?> getToken() => _messaging.getToken();

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
