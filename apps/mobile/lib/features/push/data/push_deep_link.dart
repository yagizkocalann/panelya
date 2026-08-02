import 'package:firebase_messaging/firebase_messaging.dart';

import '../domain/push_notification_repository.dart' show deepLinkDataKey;

/// [message] veri yükünden ([deepLinkDataKey]) çözülen deep-link URI'si;
/// anahtar yoksa ya da değer geçerli bir URI değilse `null` döner (bkz.
/// `FirebasePushNotificationRepository.notificationTaps` — geçersiz/eksik
/// deep-link'li mesajlar SESSİZCE atlanır, hata fırlatılmaz).
///
/// [RemoteMessage] platform kanalı çağırmayan SAF bir veri sınıfıdır (yalnız
/// alanları tutar); bu yüzden bu fonksiyon `Firebase.initializeApp()`
/// OLMADAN, testte doğrudan üretilen örneklerle çağrılabilir.
Uri? resolveDeepLink(RemoteMessage message) {
  final raw = message.data[deepLinkDataKey];
  if (raw == null) return null;
  return Uri.tryParse(raw as String);
}
