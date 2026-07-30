import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/offline_storage_provider.dart';
import '../../core/storage/shared_preferences_provider.dart';
import '../../features/push/data/firebase_push_notification_repository.dart';
import '../../features/push/presentation/push_providers.dart';
import '../app.dart';

/// Uygulama giriş noktası.
///
/// Firebase burada YALNIZ push bildirim TESLİMATI (FCM) için başlatılır —
/// Novel-Project'in Firebase VERİ katmanı (auth/Firestore) hâlâ taşınmadı
/// (bkz. ADR-019); bu, o kararın bir istisnası değil, farklı bir kaygı
/// (bkz. `features/push/domain/push_notification_repository.dart` doc
/// yorumu).
///
/// `SharedPreferences.getInstance()` ve `getApplicationDocumentsDirectory()`
/// burada BİR KEZ `await`lenir (sırasıyla cihaz-yerel "kaldığın yerden devam
/// et" kaydı için, bkz. `features/progress/`, ve çevrimdışı bölüm indirmeleri
/// için, bkz. `features/offline/`) ve ilgili provider override'larıyla
/// [ProviderScope]'a enjekte edilir; bu sayede alt katmandaki repository'ler
/// senkron kurulabilir, ekranlar ek bir yükleniyor durumuyla uğraşmaz.
///
/// Bildirim izni isteme İLK KARE'yi geciktirmemesi için `runApp` SONRASINA,
/// fire-and-forget olarak bırakılır (izin diyaloğu zaten bir sistem UI'ı —
/// Flutter'ın ilk çizimini beklemesi gerekmez).
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();
  final offlineStorageDirectory = await getApplicationDocumentsDirectory();
  await Firebase.initializeApp();
  final pushRepository = FirebasePushNotificationRepository(
    FirebaseMessaging.instance,
  );
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        offlineStorageDirectoryProvider.overrideWithValue(
          offlineStorageDirectory,
        ),
        pushNotificationRepositoryProvider.overrideWithValue(pushRepository),
      ],
      child: const PanelyaApp(),
    ),
  );

  // Bildirim izni verilirse VE kullanıcı daha önce tercihini kapatmadıysa
  // (bkz. `push_providers.dart` — `notifyNewEpisodesPreferenceKey`,
  // varsayılan `true`) sabit "panelya-new-episodes" konusuna abone olunur
  // (bkz. docs/mobile-handoff.md "FCM topic sınırı" — izin olmadan
  // abonelik YOK). Cihaz FCM token'ı hiçbir zaman Panelya API'sine
  // gönderilmez; token/yeniden abone olma tamamen Firebase SDK sınırında
  // kalır.
  final granted = await pushRepository.requestPermission();
  if (granted) {
    final wantsNewEpisodes =
        sharedPreferences.getBool(notifyNewEpisodesPreferenceKey) ?? true;
    if (wantsNewEpisodes) {
      // BEST-EFFORT: abonelik uygulamanın açılmasını engellemez. Burası
      // `runApp`ten SONRA çalışan, kullanıcı arayüzü olmayan bir arka plan
      // adımıdır; hata fırlatırsa yakalanmadan "Unhandled Exception" olarak
      // açılışa düşerdi (iOS'ta APNs token'ı henüz gelmemişken bu HER ilk
      // açılışta olur). Kullanıcı tercihi zaten açık kaldığı için bir
      // sonraki açılışta yeniden denenir; Bildirimler ekranından da elle
      // tekrar denenebilir.
      try {
        await pushRepository.subscribeToNewEpisodes();
      } on Object {
        // Sessizce geçilir: burada gösterilecek bir arayüz yok ve
        // kullanıcıya yanlışlıkla "abone oldun" izlenimi VERİLMEZ.
      }
    }
  }
}
