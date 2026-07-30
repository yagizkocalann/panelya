import 'package:flutter/foundation.dart';

import '../../../core/contracts/generated/generated.dart';

/// [AccountRepository] uygulamalarının fırlattığı tüm hataların ortak tipi
/// (bkz. `features/auth/domain/auth_exceptions.dart` -> `AuthRepositoryException`
/// ile aynı desen: çağıran yalnız bu sınıfı ve alt tiplerini yakalar, ham
/// `http`/parse istisnalarını doğrudan görmez).
@immutable
sealed class AccountRepositoryException implements Exception {
  const AccountRepositoryException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Sunucu, sözleşmedeki yapılandırılmış hata gövdesini
/// ([AccountErrorResponse]) döndürdü.
///
/// HTTP katmanının ham `AccountApiException`'ı (bkz. `core/api/api_exception.dart`)
/// `HttpAccountRepository` tarafından BUNA çevrilir; ekranlar yalnız bu
/// sealed hiyerarşiyi yakalar (aynı iki katmanlı desen: `AuthApiException`
/// -> `AuthProviderErrorException`).
///
/// `error` alanı sözleşmenin kapalı kümesinden gelir: `not_authenticated`,
/// `invalid_request`, `unsupported_action`, `reauthentication_required`,
/// `reauthentication_invalid`, `reauthentication_expired`,
/// `reauthentication_reused`, `not_found`, `conflict`, `rate_limited`,
/// `service_unavailable`.
class AccountServerException extends AccountRepositoryException {
  AccountServerException(this.error)
    : super(error.errorDescription ?? _fallbackMessage(error.error));

  final AccountErrorResponse error;

  /// Sunucu taze bir kimlik doğrulaması istiyor (bkz. sözleşmenin
  /// `reauthenticate` bayrağı ve `reauthentication_*` hata kodları).
  /// Çağıran kullanıcıyı sistem tarayıcısındaki reauth akışına
  /// yönlendirmelidir.
  bool get requiresReauthentication =>
      error.reauthenticate ||
      const {
        'reauthentication_required',
        'reauthentication_invalid',
        'reauthentication_expired',
        'reauthentication_reused',
      }.contains(error.error);

  /// Bu aksiyon kullanıcının sağlayıcısı/durumu için desteklenmiyor.
  bool get isUnsupportedAction => error.error == 'unsupported_action';

  /// Sunucu şu an bu aksiyonu karşılayamıyor (mobilde `scope: others`
  /// için bilinen fail-closed durum — bkz.
  /// `AccountRepository.revokeSessions` sınır notu).
  bool get isServiceUnavailable => error.error == 'service_unavailable';

  /// Yalnız bu süre sonra yeniden denenmeli (varsa).
  int? get retryAfterSeconds => error.retryAfterSeconds;

  static String _fallbackMessage(String code) => switch (code) {
    'not_authenticated' => 'Oturumun sona ermiş. Lütfen yeniden giriş yap.',
    'invalid_request' => 'İstek geçersiz.',
    'unsupported_action' => 'Bu işlem hesabın için desteklenmiyor.',
    'reauthentication_required' =>
      'Bu işlem için kimliğini yeniden doğrulaman gerekiyor.',
    'reauthentication_invalid' => 'Kimlik doğrulaman geçersiz.',
    'reauthentication_expired' =>
      'Kimlik doğrulamanın süresi doldu. Lütfen tekrar dene.',
    'reauthentication_reused' =>
      'Bu kimlik doğrulaması daha önce kullanılmış. Lütfen tekrar dene.',
    'not_found' => 'Kayıt bulunamadı.',
    'conflict' => 'Bu işlem şu anki durumla çelişiyor.',
    'rate_limited' => 'Çok fazla deneme yaptın. Lütfen biraz sonra dene.',
    'service_unavailable' => 'Servis şu an kullanılamıyor.',
    _ => 'Beklenmeyen bir hata oluştu.',
  };
}

/// Aktif bir oturum yokken çağrıldı — çağıranın sözleşmeyi yanlış
/// kullandığının işaretidir (sunucu hatası değil).
class AccountNotAuthenticatedException extends AccountRepositoryException {
  const AccountNotAuthenticatedException()
    : super('Aktif bir oturum yokken çağrıldı.');
}

/// Taze kimlik doğrulama akışı istemci tarafında bütünlüğünü kaybetti:
/// callback `state` uyuşmadı, `code` eksik, ya da `start` çağrılmadan
/// `complete` denendi. Bu bir sunucu hatası DEĞİLDİR.
class AccountReauthenticationException extends AccountRepositoryException {
  const AccountReauthenticationException(super.message);
}

/// Kullanıcı sistem tarayıcısındaki taze kimlik doğrulamasını iptal etti.
class AccountReauthenticationCancelledException
    extends AccountRepositoryException {
  const AccountReauthenticationCancelledException()
    : super('Kimlik doğrulama iptal edildi.');
}

/// Ağ/parse gibi, sözleşmenin yapılandırılmış hata gövdesine çevrilemeyen
/// beklenmeyen bir hata.
class AccountUnexpectedException extends AccountRepositoryException {
  const AccountUnexpectedException(super.message);
}
