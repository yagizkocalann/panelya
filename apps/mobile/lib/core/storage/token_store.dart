import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../contracts/generated/generated.dart';

/// Auth token'larinin saklandigi sinir arayuzu.
///
/// Gercek implementasyon [SecureStorageTokenStore]'dur (bkz. ADR-039:
/// "Flutter bunu yalniz isletim sistemi secure storage katmaninda tutar" —
/// iOS Keychain / Android Keystore-destekli EncryptedSharedPreferences).
/// [InMemoryTokenStore] yalniz testlerde kullanilir.
///
/// Butun metotlar `Future` doner: secure storage platform kanali her zaman
/// asenkrondur.
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

/// [TokenStore]'un gercek implementasyonu: `flutter_secure_storage`
/// uzerinden isletim sisteminin guvenli anahtarligina (iOS Keychain,
/// Android EncryptedSharedPreferences) yazar. Tum token seti TEK bir anahtar
/// altinda JSON olarak saklanir ki [write] gercekten ATOMIK tek bir platform
/// kanali cagrisi olsun (bkz. ADR-039 rotasyon kurali — ayri anahtarlarda
/// `accessToken`/`refreshToken` tutulsaydi iki ayri yazma arasinda tutarsiz
/// bir ara durum mumkun olurdu).
class SecureStorageTokenStore implements TokenStore {
  SecureStorageTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokensKey = 'panelya_auth_tokens_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthTokenResponse?> read() async {
    final raw = await _storage.read(key: _tokensKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return AuthTokenResponse.fromJson(decoded);
    } on FormatException {
      // Bozuk/eski surumden kalma bir deger: guvenli tarafta kal, oturumu
      // kaybetmis gibi davran (kullanici yeniden giris yapar) ama
      // ATLAMA/tekrar deneme dongusune girme.
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> write(AuthTokenResponse tokens) {
    return _storage.write(key: _tokensKey, value: jsonEncode(tokens.toJson()));
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: _tokensKey);
  }
}

/// [TokenStore]'un in-memory implementasyonu: sureç belleginde tutar,
/// hicbir diske yazmaz. Uygulama kapandiginda kaybolur — yalniz testlerde
/// kullanilir (bkz. `SecureStorageTokenStore` gercek/production yolu).
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
final tokenStoreProvider = Provider<TokenStore>(
  (ref) => SecureStorageTokenStore(),
);
