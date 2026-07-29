import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_auth_2_platform_interface/flutter_web_auth_2_platform_interface.dart';
import 'package:panelya_mobile/features/auth/data/auth_browser.dart';
import 'package:panelya_mobile/features/auth/domain/auth_exceptions.dart';

typedef _AuthenticateHandler =
    Future<String> Function({
      required String url,
      required String callbackUrlScheme,
      required Map<String, dynamic> options,
    });

/// `FlutterWebAuth2Platform.instance`'ı gerçek native Custom
/// Tabs/`ASWebAuthenticationSession` kanalına dokunmadan sahte bir
/// implementasyonla değiştirir (bkz. `token_store_test.dart`'taki
/// `TestFlutterSecureStoragePlatform` ile aynı desen).
class _FakeFlutterWebAuth2Platform extends FlutterWebAuth2Platform {
  _FakeFlutterWebAuth2Platform(this._handler);

  final _AuthenticateHandler _handler;

  @override
  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
    required Map<String, dynamic> options,
  }) {
    return _handler(
      url: url,
      callbackUrlScheme: callbackUrlScheme,
      options: options,
    );
  }

  @override
  Future<void> clearAllDanglingCalls() async {}
}

void main() {
  group('SystemAuthBrowser', () {
    testWidgets(
      'başarılı oturumda platformun döndürdüğü callback string\'ini Uri '
      'olarak döner',
      (tester) async {
        FlutterWebAuth2Platform.instance = _FakeFlutterWebAuth2Platform(
          ({required url, required callbackUrlScheme, required options}) async {
            return 'panelya://auth/callback?code=abc&state=xyz';
          },
        );

        const browser = SystemAuthBrowser();
        final result = await browser.authenticate(
          authorizationUrl: Uri.parse('https://issuer.example/authorize?client_id=x'),
          callbackUrlScheme: 'panelya',
        );

        expect(
          result,
          Uri.parse('panelya://auth/callback?code=abc&state=xyz'),
        );
      },
    );

    testWidgets(
      'kullanıcı sistem tarayıcısını iptal ederse (CANCELED) null döner',
      (tester) async {
        FlutterWebAuth2Platform.instance = _FakeFlutterWebAuth2Platform(
          ({required url, required callbackUrlScheme, required options}) async {
            throw PlatformException(code: 'CANCELED', message: 'User canceled login');
          },
        );

        const browser = SystemAuthBrowser();
        final result = await browser.authenticate(
          authorizationUrl: Uri.parse('https://issuer.example/authorize'),
          callbackUrlScheme: 'panelya',
        );

        expect(result, isNull);
      },
    );

    testWidgets(
      'CANCELED dışındaki bir platform hatası (ör. tarayıcı bulunamadı) '
      'AuthCallbackException olarak yüzeye çıkar — sessizce yutulmaz',
      (tester) async {
        FlutterWebAuth2Platform.instance = _FakeFlutterWebAuth2Platform(
          ({required url, required callbackUrlScheme, required options}) async {
            throw PlatformException(
              code: 'NO_BROWSER',
              message: 'No valid browser available for authentication.',
            );
          },
        );

        const browser = SystemAuthBrowser();

        await expectLater(
          browser.authenticate(
            authorizationUrl: Uri.parse('https://issuer.example/authorize'),
            callbackUrlScheme: 'panelya',
          ),
          throwsA(isA<AuthCallbackException>()),
        );
      },
    );
  });
}
