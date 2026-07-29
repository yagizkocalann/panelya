import 'package:flutter/foundation.dart';

/// "Hesabı sil" ekranının gösterdiği, silme işleminin gerçekte neyi
/// etkileyeceğine dair özet (bkz. ADR-047 "Silinecek veya anonimleştirilecek
/// verileri anlatan özet").
///
/// PROVISIONAL: elle yazılmış bir sunum modeli, üretilen bir DTO değildir
/// (bkz. `account_overview.dart`'taki aynı gerekçe). Gerçek sözleşme
/// gelince bu iki düz metin listesi, sunucunun döndürdüğü yapılandırılmış
/// bir envanterle değişebilir.
@immutable
class AccountDeletionSummary {
  const AccountDeletionSummary({
    required this.deletedItems,
    required this.anonymizedItems,
  });

  /// Kalıcı olarak silinecek öğeler (ör. profil, Auth0 kimliği, aktif
  /// oturumlar).
  final List<String> deletedItems;

  /// Silinmeyip anonimleştirilecek öğeler (ör. topluluk katkıları).
  final List<String> anonymizedItems;
}
