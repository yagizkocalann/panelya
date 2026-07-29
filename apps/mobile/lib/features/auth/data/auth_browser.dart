import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../domain/auth_exceptions.dart';

/// Sistem tarayıcısında (Custom Tabs / `ASWebAuthenticationSession`)
/// Authorization Code + PKCE oturum açma ekranını açma işinin soyut sınırı.
///
/// Embedded WebView KULLANILMAZ (bkz. ADR-039) — bu sınır kasıtlı olarak
/// işletim sisteminin kendi güvenli tarayıcı oturumunu (kullanıcının
/// mevcut çerezlerini/SSO durumunu paylaşan, uygulamanın DOM'a erişemediği)
/// varsayar.
abstract class AuthBrowser {
  /// [authorizationUrl]'i sistem tarayıcısında açar ve
  /// [callbackUrlScheme] (`panelya`) şemasına geri yönlendirilene kadar
  /// bekler.
  ///
  /// Kullanıcı tarayıcı sekmesini/ekranını iptal ederse `null` döner
  /// (çağıran bunu [AuthUserCancelledException] olarak yorumlar, bkz.
  /// `auth_repository.dart`); aksi halde tam callback URI'sini döner (bkz.
  /// `isAuthCallbackUri`, `app/router/deep_link.dart`).
  Future<Uri?> authenticate({
    required Uri authorizationUrl,
    required String callbackUrlScheme,
  });
}

/// [AuthBrowser]'ın gerçek implementasyonu: `flutter_web_auth_2` üzerinden
/// işletim sisteminin kendi güvenli oturumunu (iOS'ta
/// `ASWebAuthenticationSession`, Android'de Custom Tabs) açar.
///
/// `preferEphemeral` KASITLI OLARAK ayarlanmaz (varsayılan `false` kalır):
/// ADR-039'un tarif ettiği "kullanıcının mevcut çerezlerini/SSO durumunu
/// paylaşan" sistem tarayıcı oturumu tam olarak bu demektir — kullanıcı
/// zaten web'de Auth0 ile oturum açmışsa mobilde de tekrar şifre girmesi
/// gerekmez. Callback URI'yi bu paketin kendisi yakalar (bkz.
/// `app/router/deep_link.dart` — `resolveCustomSchemeRoute` bilerek
/// `panelya://auth/callback`'i bu yüzden işlemez).
class SystemAuthBrowser implements AuthBrowser {
  const SystemAuthBrowser();

  @override
  Future<Uri?> authenticate({
    required Uri authorizationUrl,
    required String callbackUrlScheme,
  }) async {
    try {
      final result = await FlutterWebAuth2.authenticate(
        url: authorizationUrl.toString(),
        callbackUrlScheme: callbackUrlScheme,
      );
      return Uri.parse(result);
    } on PlatformException catch (error) {
      if (error.code == 'CANCELED') return null;
      // `flutter_web_auth_2` her iki platformda da kullanıcı iptalini
      // `CANCELED` koduyla bildirir (bkz. paketin iOS/Android native
      // kaynağı); bunun dışındaki her kod (`FAILED`, `NO_BROWSER`,
      // `EUNKNOWN`, ...) gerçek bir tarayıcı/platform hatasıdır ve
      // istemci tarafı bütünlük hatası olarak yüzeye çıkar (bkz.
      // `AuthCallbackException` — `AccountScreen` bunu zaten [AppErrorView]
      // ile gösterir).
      throw AuthCallbackException(
        'Sistem tarayıcısı oturumu tamamlanamadı: ${error.message ?? error.code}',
      );
    }
  }
}
