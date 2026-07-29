import 'package:flutter/foundation.dart';

import '../../../core/contracts/generated/generated.dart';
import 'account_provider.dart';

/// "Hesabım" ana ekranının gösterdiği birleşik kimlik özeti.
///
/// PROVISIONAL: elle yazılmış bir sunum modeli, `core/contracts/generated/`
/// altındaki üretilen DTO'lardan BİRİ DEĞİLDİR — ADR-047'nin gerçek
/// `/api/account/*` sözleşmesi gelince kaldırılması/değiştirilmesi
/// beklenir.
///
/// Bilerek [AuthUser]'ı (bkz. `authSessionProvider`'dan gelen gerçek oturum
/// kullanıcısı) KOPYALAMAZ, yalnız SARAR: `displayName`/`email`/
/// `emailVerified`/`avatarUrl` zaten [AuthUser]'da var. Böylece gerçek bir
/// Auth0 oturumuyla girişte kullanıcı, kendi gerçek kimliğinin yanında
/// bağlantısız/sahte bir isim-e-posta GÖRMEZ (bkz.
/// `account_providers.dart` -> `accountOverviewProvider`, iki kaynağı
/// birleştiren yer).
@immutable
class AccountOverview {
  const AccountOverview({required this.user, required this.provider});

  final AuthUser user;
  final AccountProvider provider;
}
