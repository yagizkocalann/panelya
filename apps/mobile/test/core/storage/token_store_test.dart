import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/core/storage/token_store.dart';

const _user = AuthUser(
  id: 'test-user',
  displayName: 'Test Kullanıcı',
  email: 'test-user@panelya.invalid',
  emailVerified: true,
  role: 'reader',
);

AuthTokenResponse _tokens({String suffix = ''}) => AuthTokenResponse(
  schemaVersion: kSchemaVersion,
  tokenType: 'Bearer',
  accessToken: 'test-access-token$suffix',
  expiresIn: 900,
  refreshToken: 'test-refresh-token$suffix',
  scope: const ['openid'],
  user: _user,
);

/// [InMemoryTokenStore] sınır testleri (bkz. PLAN "TokenStore sınırı").
/// Arayüzün kendisi zaten async tasarlanmıştır (gelecekteki secure storage
/// implementasyonunu beklemek için, bkz. `token_store.dart` dokümantasyonu);
/// bu testler yalnız bugünkü in-memory implementasyonun sözleşmesini
/// (yaz/oku/temizle, cihaz kalıcılığı yok) doğrular.
void main() {
  group('InMemoryTokenStore', () {
    test('read() returns null before anything has been written', () async {
      final store = InMemoryTokenStore();
      expect(await store.read(), isNull);
    });

    test('write() then read() returns the same token set', () async {
      final store = InMemoryTokenStore();
      final tokens = _tokens();

      await store.write(tokens);
      final read = await store.read();

      expect(read, isNotNull);
      expect(read!.accessToken, tokens.accessToken);
      expect(read.refreshToken, tokens.refreshToken);
      expect(read.user.id, tokens.user.id);
    });

    test('a second write() atomically replaces the previous value', () async {
      final store = InMemoryTokenStore();
      await store.write(_tokens(suffix: '-1'));
      await store.write(_tokens(suffix: '-2'));

      final read = await store.read();
      expect(read!.accessToken, 'test-access-token-2');
      expect(read.refreshToken, 'test-refresh-token-2');
    });

    test('clear() removes the stored token set', () async {
      final store = InMemoryTokenStore();
      await store.write(_tokens());
      await store.clear();

      expect(await store.read(), isNull);
    });

    test('clear() on an already-empty store is a safe no-op', () async {
      final store = InMemoryTokenStore();
      await store.clear();
      expect(await store.read(), isNull);
    });

    test(
      'two independent InMemoryTokenStore instances never share state '
      '(no hidden static/global storage)',
      () async {
        final first = InMemoryTokenStore();
        final second = InMemoryTokenStore();

        await first.write(_tokens());

        expect(await first.read(), isNotNull);
        expect(await second.read(), isNull);
      },
    );
  });

  group('SecureStorageTokenStore', () {
    late Map<String, String> backingStore;

    setUp(() {
      // `FlutterSecureStoragePlatform.instance`'ı gerçek Keychain/Keystore
      // platform kanalı yerine bellek içi sahte bir implementasyonla
      // değiştirir (bkz. `flutter_secure_storage`'ın kendi test yardımcısı);
      // böylece bu testler bir `TestWidgetsFlutterBinding` gerektirmeden,
      // gerçek native koda dokunmadan çalışır.
      backingStore = <String, String>{};
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
        backingStore,
      );
    });

    test('read() returns null before anything has been written', () async {
      final store = SecureStorageTokenStore();
      expect(await store.read(), isNull);
    });

    test('write() then read() returns the same token set', () async {
      final store = SecureStorageTokenStore();
      final tokens = _tokens();

      await store.write(tokens);
      final read = await store.read();

      expect(read, isNotNull);
      expect(read!.accessToken, tokens.accessToken);
      expect(read.refreshToken, tokens.refreshToken);
      expect(read.user.id, tokens.user.id);
    });

    test(
      'a second write() atomically replaces the previous value under a '
      'SINGLE platform key (bkz. ADR-039 rotasyon kuralı)',
      () async {
        final store = SecureStorageTokenStore();
        await store.write(_tokens(suffix: '-1'));
        await store.write(_tokens(suffix: '-2'));

        expect(backingStore.length, 1);
        final read = await store.read();
        expect(read!.accessToken, 'test-access-token-2');
        expect(read.refreshToken, 'test-refresh-token-2');
      },
    );

    test('clear() removes the stored token set', () async {
      final store = SecureStorageTokenStore();
      await store.write(_tokens());
      await store.clear();

      expect(await store.read(), isNull);
    });

    test(
      'a corrupted/legacy non-JSON stored value fails closed to null '
      'instead of throwing',
      () async {
        backingStore['panelya_auth_tokens_v1'] = 'not-json';
        final store = SecureStorageTokenStore();

        expect(await store.read(), isNull);
      },
    );

    test(
      'valid JSON that does not match the AuthTokenResponse shape fails '
      'closed to null instead of throwing',
      () async {
        backingStore['panelya_auth_tokens_v1'] = '{"unexpected": true}';
        final store = SecureStorageTokenStore();

        expect(await store.read(), isNull);
      },
    );
  });
}
