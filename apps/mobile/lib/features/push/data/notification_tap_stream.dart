import 'package:firebase_messaging/firebase_messaging.dart';

import 'push_deep_link.dart';

/// Soğuk başlangıçta bekleyen bir bildirim varsa ([getInitialMessage]) onun
/// deep-link'ini İLK ÖNCE yayınlar, ardından [onMessageOpenedApp]
/// akışından gelen (uygulama arka plandayken dokunulan) bildirimlerin
/// deep-link'lerini yayınlar (bkz.
/// `FirebasePushNotificationRepository.notificationTaps` doc yorumu).
///
/// Deep-link'i çözülemeyen ([resolveDeepLink] `null` dönen) mesajlar
/// SESSİZCE atlanır — hata değildir ama akışa da YANSIMAZ.
///
/// Firebase'in statik `onMessageOpenedApp` akışına DOĞRUDAN bağlanmak
/// yerine bunu parametre olarak almak, bu birleştirme mantığının
/// `Firebase.initializeApp()` OLMADAN test edilebilmesini sağlar —
/// [RemoteMessage] platform kanalı çağırmayan saf bir veri sınıfı olduğu
/// için testler gerçek örnekler oluşturup sahte bir akıştan besleyebilir.
Stream<Uri> notificationTapStream({
  required Future<RemoteMessage?> Function() getInitialMessage,
  required Stream<RemoteMessage> onMessageOpenedApp,
}) async* {
  final initial = await getInitialMessage();
  final initialUri = initial == null ? null : resolveDeepLink(initial);
  if (initialUri != null) yield initialUri;

  yield* onMessageOpenedApp
      .map(resolveDeepLink)
      .where((uri) => uri != null)
      .cast<Uri>();
}
