import '../../../core/contracts/generated/generated.dart';

/// Kütüphane katmanının domain hata hiyerarşisi (bkz.
/// `account_exceptions.dart` ile aynı desen). Ekranlar HTTP/parse
/// ayrıntısını değil yalnız bu tipleri görür.
sealed class LibraryRepositoryException implements Exception {
  const LibraryRepositoryException();

  String get message;
}

/// Saklı bir oturum yok — istek sunucuya HİÇ gönderilmedi.
///
/// ADR-010: bu durumda sahte başarı ÜRETİLMEZ. Çağıran, kullanıcıyı
/// mevcut GERÇEK Auth0 giriş akışına yönlendirmelidir (bkz.
/// `AccountScreen`).
class LibraryNotAuthenticatedException extends LibraryRepositoryException {
  const LibraryNotAuthenticatedException();

  @override
  String get message => 'Bu işlem için giriş yapmalısın.';
}

/// Sunucu sözleşmeye uygun, YAPILANDIRILMIŞ bir hata gövdesi döndü.
/// Sunucunun kendi açıklaması varsa kullanıcıya o gösterilir.
class LibraryServerException extends LibraryRepositoryException {
  const LibraryServerException(this.error);

  final LibraryErrorResponse error;

  bool get isNotAuthenticated => error.error == 'not_authenticated';

  @override
  String get message =>
      error.errorDescription ?? 'İşlem tamamlanamadı. Tekrar dene.';
}

/// Ağ/parse gibi sözleşme dışı arızalar.
class LibraryUnexpectedException extends LibraryRepositoryException {
  const LibraryUnexpectedException(this.message);

  @override
  final String message;
}
