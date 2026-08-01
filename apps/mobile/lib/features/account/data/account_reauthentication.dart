import '../../../app/router/deep_link.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../auth/data/auth_browser.dart';
import '../../auth/data/pkce.dart';
import '../domain/account_exceptions.dart';
import '../domain/account_repository.dart';

/// Taze kimlik doğrulama (reauthentication) akışının orkestratörü (bkz.
/// ADR-047, docs/production-account-lifecycle.md).
///
/// AKIŞ:
///   1. İstemci bir PKCE çifti üretir ve `codeChallenge`'ı
///      `POST /api/account/reauthentication/start`e gönderir; sunucu
///      `requestId` + `authorizationUrl` döner.
///   2. `authorizationUrl` SİSTEM TARAYICISINDA açılır (embedded WebView
///      yok, bkz. ADR-039) ve callback yakalanır.
///   3. Callback'ten `code` + `state` alınıp `codeVerifier` ile
///      `POST /api/account/reauthentication/complete`e gönderilir; sunucu
///      AMACA BAĞLI, kısa ömürlü, TEK KULLANIMLIK bir
///      `reauthenticationToken` döner.
///   4. Bu token YALNIZ ilgili mutation'da (e-posta değiştirme veya hesap
///      silme) kullanılır.
///
/// KRİTİK SINIRLAR:
/// - Authorization code hiçbir zaman bir mutation'a DOĞRUDAN verilmez;
///   yalnız `complete` ucuna gider ve karşılığında token alınır.
/// - Bu akış mevcut `AuthRepository` oturumunu ve `TokenStore`'u
///   DEĞİŞTİRMEZ: `completeSignIn`/`refresh`/`logout` ÇAĞRILMAZ, token
///   deposuna YAZILMAZ. Yalnız `AccountRepository`nin iki ucu ve
///   `AuthBrowser` kullanılır.
/// - `codeVerifier` bu sınıfın içinde kalır; çağırana sızdırılmaz ve
///   loglanmaz.
class AccountReauthenticator {
  const AccountReauthenticator({
    required AccountRepository repository,
    required AuthBrowser browser,
  }) : _repository = repository,
       _browser = browser;

  // ignore_for_file: prefer_initializing_formals
  // Alanlar private (`_repository`/`_browser`); çağıranın gördüğü
  // parametre adları ise public (`repository`/`browser`). Bu ayrım
  // bilinçli — initializing formal (`this._repository`) private adı
  // public API'ye sızdırırdı.

  final AccountRepository _repository;
  final AuthBrowser _browser;

  /// Verilen [purpose] için uçtan uca taze kimlik doğrulaması yapar ve
  /// mutation'da kullanılacak `reauthenticationToken`'ı döner.
  ///
  /// Fırlatabilir:
  /// - [AccountReauthenticationCancelledException] — kullanıcı sistem
  ///   tarayıcısını kapattı (çağıran bunu sessizce ele alır, hata
  ///   göstermez).
  /// - [AccountReauthenticationException] — callback bütünlük hatası
  ///   (eksik `code`/`state`, beklenmeyen callback URI).
  /// - [AccountServerException] — sunucu tarafı hata (ör.
  ///   `reauthentication_expired`).
  Future<String> obtainToken(AccountReauthenticationPurpose purpose) async {
    final pkce = PkcePair.generate();

    final start = await _repository.startReauthentication(
      purpose: purpose,
      redirectUri: authCallbackRedirectUri,
      codeChallenge: pkce.challenge,
    );

    final callbackUri = await _browser.authenticate(
      authorizationUrl: Uri.parse(start.authorizationUrl),
      callbackUrlScheme: start.callbackUrlScheme,
    );
    if (callbackUri == null) {
      throw const AccountReauthenticationCancelledException();
    }
    if (!isAuthCallbackUri(callbackUri)) {
      throw const AccountReauthenticationException(
        'Beklenmeyen callback URI: panelya://auth/callback biçiminde değil.',
      );
    }

    final params = callbackUri.queryParameters;
    if (params['error'] == 'access_denied') {
      throw const AccountReauthenticationCancelledException();
    }

    final code = params['code'];
    if (code == null || code.isEmpty) {
      throw const AccountReauthenticationException(
        'Kimlik doğrulama callback\'inde code parametresi eksik.',
      );
    }
    // `state` doğrulaması SUNUCUDA yapılır (sözleşme `state`'i
    // `complete` isteğinin zorunlu alanı olarak tanımlar ve `requestId`
    // ile eşler); istemci onu üretmediği için burada karşılaştıramaz —
    // yalnız varlığını kontrol eder ve olduğu gibi iletir.
    final state = params['state'];
    if (state == null || state.isEmpty) {
      throw const AccountReauthenticationException(
        'Kimlik doğrulama callback\'inde state parametresi eksik.',
      );
    }

    final completed = await _repository.completeReauthentication(
      requestId: start.requestId,
      authorizationCode: code,
      state: state,
      codeVerifier: pkce.verifier,
      redirectUri: authCallbackRedirectUri,
    );

    if (completed.purpose != purpose) {
      // Sunucu farklı bir amaç için token döndürdü — token AMACA BAĞLI
      // olduğu için bu kullanılamaz (savunma kontrolü).
      throw const AccountReauthenticationException(
        'Kimlik doğrulama tokeni beklenen amaç için verilmedi.',
      );
    }

    return completed.reauthenticationToken;
  }
}
