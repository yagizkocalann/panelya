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

/// [AuthBrowser]'ın tek implementasyonu — bilerek bir STUB'tır.
///
/// Gerçek bir sistem tarayıcı oturumu açmak `url_launcher` (veya
/// `flutter_web_auth_2`/Auth0'ın resmi Flutter SDK'si) gibi bir platform
/// kanalı paketi gerektirir; bu paket, gerekçesiyle birlikte, gerçek Auth0
/// tenant/gateway/JWKS değerleri sağlandığında eklenecektir (bkz. görev
/// talimatı "url_launcher EKLEME"). Bu sınıf o ana kadar arayüzün
/// varlığını ve `HttpAuthRepository`'nin ona bağımlılığını sabitler;
/// çağrılırsa (bugün hiçbir yerden çağrılmaz) açık bir hata fırlatır —
/// sessizce yanlış/boş bir URI döndürmez.
class SystemAuthBrowser implements AuthBrowser {
  const SystemAuthBrowser();

  @override
  Future<Uri?> authenticate({
    required Uri authorizationUrl,
    required String callbackUrlScheme,
  }) {
    throw UnimplementedError(
      'SystemAuthBrowser: gerçek sistem tarayıcı entegrasyonu (url_launcher '
      'veya Auth0 resmi Flutter SDK) henüz eklenmedi; gerçek Auth0 '
      'tenant/gateway/JWKS değerleri sağlanınca eklenecek (bkz. '
      'docs/production-auth-session.md, "Kalan deployment kapıları").',
    );
  }
}
