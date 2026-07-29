import 'package:flutter/foundation.dart';

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

/// Aktif bir oturum yokken çağrıldı (bkz. `AuthNotAuthenticatedException`
/// ile aynı gerekçe — bu bir sunucu hatası değil, çağıranın sözleşmeyi
/// yanlış kullandığının işaretidir).
class AccountNotAuthenticatedException extends AccountRepositoryException {
  const AccountNotAuthenticatedException()
    : super('Aktif bir oturum yokken çağrıldı.');
}

/// Hesabı sil gibi hassas bir işlem, taze bir kimlik doğrulaması
/// gerektiriyor ama sağlanan [AccountRepository.deleteAccount]
/// `reauthCredential`'ı sağlayıcı tarafından geçersiz/süresi dolmuş
/// bulundu — çağıran kullanıcıyı sistem tarayıcısında yeniden kimlik
/// doğrulamaya yönlendirmelidir.
class AccountReauthRequiredException extends AccountRepositoryException {
  const AccountReauthRequiredException(super.message);
}

/// İstenen aksiyon, kullanıcının giriş sağlayıcısı için desteklenmiyor
/// (ör. Google ile giriş yapmış bir kullanıcı için e-posta değiştirme).
/// Ekranlar bunu normalde hiç fırlatılmayacak şekilde önler (bkz.
/// `AccountProviderX`), ama sözleşme yine de açıkça tanımlar.
class AccountActionNotSupportedException extends AccountRepositoryException {
  const AccountActionNotSupportedException(super.message);
}

/// Sağlayıcı/ağ tarafından beklenmeyen bir hata döndü.
class AccountUnexpectedException extends AccountRepositoryException {
  const AccountUnexpectedException(super.message);
}
