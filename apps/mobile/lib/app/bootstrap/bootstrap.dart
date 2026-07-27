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
/// Bildirim izni isteme ve token loglama İLK KARE'yi geciktirmemesi için
/// `runApp` SONRASINA, fire-and-forget olarak bırakılır (izin diyaloğu
/// zaten bir sistem UI'ı — Flutter'ın ilk çizimini beklemesi gerekmez).
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

  await pushRepository.requestPermission();
  // Backend'in cihaz token kaydı uç noktası henüz yok (bkz.
  // `push_notification_repository.dart` doc yorumu); bu ara dönemde
  // gerçek teslimi Firebase Console'un "Send test message" özelliğiyle
  // doğrulamak için token'ı debug konsoluna basıyoruz.
  final token = await pushRepository.getToken();
  debugPrint('FCM device token: $token');
}
