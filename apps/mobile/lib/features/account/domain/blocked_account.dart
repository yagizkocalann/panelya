import 'package:flutter/foundation.dart';

/// Kullanıcının engellediği bir hesabın "Engellenen hesaplar" ekranında
/// gösterilecek özeti.
///
/// PROVISIONAL: elle yazılmış bir sunum modeli, üretilen bir DTO değildir
/// (bkz. `account_overview.dart`'taki aynı gerekçe).
@immutable
class BlockedAccount {
  const BlockedAccount({
    required this.id,
    required this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
}
