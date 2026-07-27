import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/push_notification_repository.dart';

/// Aktif [PushNotificationRepository]. `bootstrap()` içinde
/// `Firebase.initializeApp()` tamamlandıktan SONRA gerçek bir
/// `FirebasePushNotificationRepository` ile override edilir (bkz.
/// `sharedPreferencesProvider`/`offlineStorageDirectoryProvider` ile aynı
/// desen — async kurulum gerektiren bir kaynak, senkron okunabilsin diye
/// `ProviderScope` override'ıyla enjekte edilir).
final pushNotificationRepositoryProvider = Provider<PushNotificationRepository>(
  (ref) {
    throw UnimplementedError(
      'pushNotificationRepositoryProvider, bootstrap() (veya test '
      'kurulumunda) override edilmeden önce okunamaz.',
    );
  },
);

/// Arka planda/kapalıyken dokunulan bir bildirimin çözülen deep-link
/// URI'si (bkz. `PushNotificationRepository.notificationTaps`). Kök widget
/// (`app.dart`) bunu dinleyip go_router ile ilgili rotaya gider.
final pendingNotificationRouteProvider = StreamProvider<Uri>((ref) {
  return ref.watch(pushNotificationRepositoryProvider).notificationTaps;
});
