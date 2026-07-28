import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/shared_preferences_provider.dart';
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

/// Yeni bölüm bildirimi tercihinin cihaz-yerel anahtarı (bkz.
/// [NotificationPreferenceNotifier]).
const notifyNewEpisodesPreferenceKey = 'push_notify_new_episodes';

/// Kullanıcının "yeni bölüm bildirimi" tercihi — cihaz-yerel
/// (`SharedPreferences`), hesap/giriş gerektirmez. Varsayılan `true`:
/// bildirim izni verildiğinde `bootstrap()` bu tercihi okuyup varsayılan
/// olarak konuya abone olur (bkz. `bootstrap.dart`); kullanıcı burada
/// açıkça kapatırsa [NotificationSettingsScreen] aboneliği de kaldırır.
class NotificationPreferenceNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref
            .watch(sharedPreferencesProvider)
            .getBool(notifyNewEpisodesPreferenceKey) ??
        true;
  }

  Future<void> setEnabled(bool value) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(notifyNewEpisodesPreferenceKey, value);
    state = value;
  }
}

final notificationPreferenceProvider =
    NotifierProvider<NotificationPreferenceNotifier, bool>(
      NotificationPreferenceNotifier.new,
    );

/// Bildirim iznin GERÇEK zamanlı OS durumu (kullanıcı ayarlardan izni geri
/// almış olabilir) — [NotificationSettingsScreen]'in anahtarın gerçekten
/// etkili olup olmadığını doğru göstermesi için.
final pushPermissionStatusProvider = FutureProvider<bool>((ref) {
  return ref.watch(pushNotificationRepositoryProvider).hasPermission();
});
