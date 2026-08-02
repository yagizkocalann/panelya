import 'package:firebase_messaging/firebase_messaging.dart';

/// iOS izin diyaloğunda kullanıcı "Şimdilik izin ver" (provisional/sessiz
/// bildirim) seçebilir; bu da bir onay sayılır (bkz.
/// `FirebasePushNotificationRepository.requestPermission`/`hasPermission`).
/// Yalnız [AuthorizationStatus.authorized] VE [AuthorizationStatus.provisional]
/// "izin verildi" sayılır; [AuthorizationStatus.denied] ve
/// [AuthorizationStatus.notDetermined] sayılmaz.
///
/// [AuthorizationStatus] platform kanalı çağırmayan bir enum'dur; bu yüzden
/// bu fonksiyon `Firebase.initializeApp()` OLMADAN test edilebilir.
bool isAuthorizedStatus(AuthorizationStatus status) =>
    status == AuthorizationStatus.authorized ||
    status == AuthorizationStatus.provisional;
