import 'package:flutter/foundation.dart';

/// Bir oturumun açıldığı platform (bkz. "Aktif oturumlar" ekranı,
/// ADR-047).
///
/// PROVISIONAL: gerçek `/api/account/sessions` sözleşmesi gelince bu
/// kümenin tam değerleri (ör. ek platformlar) değişebilir.
enum AccountSessionPlatform { web, android, ios }

/// Bir aktif oturumun mobil tarafta gösterilecek özeti.
///
/// PROVISIONAL: elle yazılmış bir sunum modeli, üretilen bir DTO değildir
/// (bkz. `account_overview.dart`'taki aynı gerekçe).
@immutable
class AccountSession {
  const AccountSession({
    required this.id,
    required this.deviceLabel,
    required this.platform,
    required this.lastActiveAt,
    required this.isCurrentDevice,
  });

  final String id;
  final String deviceLabel;
  final AccountSessionPlatform platform;
  final DateTime lastActiveAt;

  /// Bu oturum, işlemin çalıştığı MEVCUT mobil cihaza mı ait. `true` ise
  /// "Aktif oturumlar" ekranında "Bu cihaz" rozeti gösterilir ve bu
  /// oturum kapatıldığında uygulama yerel olarak da güvenli şekilde çıkış
  /// durumuna alınır (bkz. `sessions_screen.dart`).
  final bool isCurrentDevice;
}
