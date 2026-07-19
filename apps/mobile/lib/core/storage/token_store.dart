import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contracts/generated/generated.dart';

/// Auth token'larinin saklandigi sinir arayuzu.
///
/// Kapsam (bkz. PLAN "Secure storage siniri"): bugun yalniz [InMemoryTokenStore]
/// yazilir; `flutter_secure_storage` (veya baska bir platform-kanali
/// depolama paketi) BURADA EKLENMEZ. Gercek tenant/gateway entegrasyonu
/// geldiginde (bkz. ADR-039 "Access token ... yalniz isletim sistemi secure
/// storage katmaninda tutar") ayni arayuzun arkasina, gerekcesiyle birlikte,
/// isletim sistemi anahtarligina yazan yeni bir implementasyon eklenecek —
/// cagiran kod (repository/provider) DEGISMEYECEK.
///
/// Butun metotlar kasitli olarak `Future` doner: [InMemoryTokenStore] bunu
/// senkron da karsilayabilirdi, ama arayuz simdiden gelecekteki
/// asenkron-zorunlu implementasyonu (secure storage platform kanali her
/// zaman asenkrondur) bekleyecek sekilde tasarlandi; boylece gecis tek
/// noktadan (bu dosyadaki fabrika/provider) yapilir, cagiran kod hicbir
/// yerde degismez.
///
/// Token DEGERLERI hicbir zaman log/print/analytics/audit olayina yazilmaz
/// (bkz. ADR-039 "Guvenlik notlari").
abstract class TokenStore {
  /// Su anda saklanan token seti; hic oturum yoksa `null`.
  Future<AuthTokenResponse?> read();

  /// Onceki degeri ATOMIK olarak yeni degerle degistirir (bkz. ADR-039:
  /// "yeni refresh tokeni atomik olarak yazmadan eskisini silmez" — bu
  /// yuzden rotasyon `clear()` + `write()` olarak DEGIL, tek bir `write()`
  /// cagrisi olarak yapilir).
  Future<void> write(AuthTokenResponse tokens);

  /// Saklanan token setini siler (logout/revoke sonrasi).
  Future<void> clear();
}

/// [TokenStore]'un tek implementasyonu: sureç belleginde tutar, hicbir
/// diske/`SharedPreferences`'a yazmaz. Uygulama kapandiginda kaybolur; bu
/// bilinen ve kabul edilen bir sinirdir (gercek tenant gelene kadar canli
/// bir login akisi zaten yok, bkz. gorev talimati "ADAPTER SINIRI").
class InMemoryTokenStore implements TokenStore {
  AuthTokenResponse? _tokens;

  @override
  Future<AuthTokenResponse?> read() async => _tokens;

  @override
  Future<void> write(AuthTokenResponse tokens) async {
    _tokens = tokens;
  }

  @override
  Future<void> clear() async {
    _tokens = null;
  }
}

/// Aktif [TokenStore]. Uygulama genelinde tek bir ornek paylasilir (ayni
/// [sharedPreferencesProvider] deseninde, bkz. `shared_preferences_provider.dart`)
/// ki farkli repository'ler ayni oturumu gorsun.
final tokenStoreProvider = Provider<TokenStore>((ref) => InMemoryTokenStore());
