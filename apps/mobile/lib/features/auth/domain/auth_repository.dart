import 'package:flutter/foundation.dart';

import 'auth_session_state.dart';

/// Sistem tarayıcısında açılacak yetkilendirme isteği (bkz. ADR-039:
/// Authorization Code + PKCE, embedded WebView yok).
///
/// `code_verifier` ve CSRF `state` değerleri BURADA taşınmaz — repository
/// içinde tutulur (bkz. implementasyonlardaki `_pendingPkce`/`_pendingState`
/// alanları) ki dışarıdan yanlışlıkla kaybedilemesin/loglanamasın; çağıran
/// yalnız [authorizationUrl]'i sistem tarayıcısında açar ve dönen URI'yi
/// [AuthRepository.completeSignIn]'e verir.
@immutable
class AuthorizationRequest {
  const AuthorizationRequest({
    required this.authorizationUrl,
    required this.callbackUrlScheme,
  });

  /// Sistem tarayıcısında açılacak tam URL (`code_challenge`/`state`
  /// dahil).
  final Uri authorizationUrl;

  /// [AuthBrowser.authenticate]'e geçilecek callback şeması (`panelya`).
  final String callbackUrlScheme;
}

/// Panelya kimlik doğrulama sınırının tek soyut sözleşmesi.
///
/// İki implementasyon vardır (bkz. `features/auth/data/`):
/// - `FakeAuthRepository` — in-memory sahte, testler ve geliştirme için.
///   Bugün Riverpod provider'ları BUNU bağlar (bkz.
///   `features/auth/presentation/auth_providers.dart`).
/// - `HttpAuthRepository` — gerçek `/api/auth/*` uçlarına konuşan iskelet;
///   gerçek Auth0 tenant/gateway/JWKS değerleri sağlanana kadar hiçbir
///   provider'dan bağlanmaz (bkz. o dosyadaki sınır notu).
///
/// Geçiş tek noktadan yapılır: `authRepositoryProvider` içindeki tek satır.
/// Ekranlar (ileride eklenecek) bu arayüzü yalnız `authSessionProvider`
/// üzerinden, Riverpod provider'ları aracılığıyla kullanır — hiçbir ekran
/// bir implementasyonu doğrudan örneklemez.
abstract class AuthRepository {
  /// Şu anki oturum durumu; senkron erişim (bkz. [stateChanges] için
  /// akış).
  AuthSessionState get currentState;

  /// [currentState] değiştiğinde yayılan akış. Yeni bir dinleyici akışa
  /// abone olduğunda önce mevcut durumu, sonra sonraki değişiklikleri alır
  /// (implementasyonlar bunu garanti eder — bkz. `FakeAuthRepository`/
  /// `HttpAuthRepository`'deki `stateChanges` getter'ı).
  Stream<AuthSessionState> get stateChanges;

  /// PKCE çiftini üretir, CSRF `state`'ini oluşturur ve sistem
  /// tarayıcısında açılacak yetkilendirme isteğini döner. Aynı anda yalnız
  /// bir bekleyen istek olabilir; yeni bir çağrı öncekini geçersiz kılar.
  Future<AuthorizationRequest> beginSignIn();

  /// Sistem tarayıcısından dönen callback URI'sini işler: `state`'i
  /// doğrular, `code`'u [beginSignIn] sırasında üretilen `code_verifier`
  /// ile değiştirir, başarılıysa [currentState]'i [AuthAuthenticated]'e
  /// taşır.
  ///
  /// Fırlatabilir: [AuthUserCancelledException] (kullanıcı iptal etti,
  /// `error=access_denied`), [AuthCallbackException] (state uyuşmazlığı,
  /// eksik `code`, bekleyen istek yok), [AuthProviderErrorException]
  /// (sağlayıcı/gateway hatası).
  Future<void> completeSignIn(Uri callbackUri);

  /// Dönen refresh tokeni kullanarak yeni bir access + refresh tokeni
  /// alır (bkz. ADR-039 rotasyon kuralı). Aktif oturum yoksa
  /// [AuthNotAuthenticatedException] fırlatır.
  Future<void> refresh();

  /// Refresh grantini iptal eder, [TokenStore]'u temizler ve
  /// [currentState]'i [AuthAnonymous]'a taşır. Aktif oturum yokken
  /// çağrılması da güvenlidir (no-op, zaten anonim).
  Future<void> logout();

  /// Akış controller'ını kapatır. Yalnız Riverpod `ref.onDispose` içinde
  /// çağrılmalıdır.
  void dispose();
}
