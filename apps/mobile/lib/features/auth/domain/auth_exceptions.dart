import 'package:flutter/foundation.dart';

import '../../../core/contracts/generated/generated.dart';

/// [AuthRepository] uygulamalarının fırlattığı tüm hataların ortak tipi
/// (bkz. `core/api/api_exception.dart` — `ApiException` ile aynı desen:
/// çağıran yalnız bu sınıfı ve alt tiplerini yakalar, ham `http`/parse
/// istisnalarını doğrudan görmez).
@immutable
sealed class AuthRepositoryException implements Exception {
  const AuthRepositoryException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Kullanıcı sistem tarayıcısındaki oturum açma ekranını iptal etti/kapattı
/// (bkz. `AuthBrowser.authenticate` -> `null` dönüşü).
class AuthUserCancelledException extends AuthRepositoryException {
  const AuthUserCancelledException()
    : super('Kullanıcı oturum açmayı iptal etti.');
}

/// Sistem tarayıcısından dönen callback URI beklenen şekilde değil: `state`
/// eşleşmiyor (CSRF koruması), `code` eksik, ya da `beginSignIn()`
/// çağrılmadan callback alındı. Bu hiçbir zaman sunucudan gelen bir hata
/// DEĞİLDİR — tamamen istemci tarafı bütünlük kontrolüdür.
class AuthCallbackException extends AuthRepositoryException {
  const AuthCallbackException(super.message);
}

/// Sağlayıcı/gateway açık bir hata kodu döndürdü (bkz. `AuthErrorResponse`,
/// ADR-039 "Oturum ve hata kuralları"). `error` alanı bilinen kod kümesini
/// taşır: `token_reused`, `session_revoked`, `token_expired`,
/// `login_required`, `rate_limited`, `service_unavailable`, ...
class AuthProviderErrorException extends AuthRepositoryException {
  AuthProviderErrorException(this.error)
    : super(error.errorDescription ?? error.error);

  final AuthErrorResponse error;

  /// ADR-039: bu kodlardan biri geldiğinde istemci secure storage'ı
  /// temizleyip kullanıcıyı yeniden girişe götürmelidir.
  bool get requiresReauthentication => error.reauthenticate;
}

/// `refresh()`/`logout()` aktif bir oturum yokken çağrıldı (TokenStore
/// boş). Bu bir sunucu hatası değil, çağıranın sözleşmeyi yanlış
/// kullandığının işaretidir.
class AuthNotAuthenticatedException extends AuthRepositoryException {
  const AuthNotAuthenticatedException()
    : super('Aktif bir oturum yokken çağrıldı.');
}
