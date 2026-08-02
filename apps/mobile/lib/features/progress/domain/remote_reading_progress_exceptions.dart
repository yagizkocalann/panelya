import '../../../core/contracts/generated/generated.dart';

/// Uzak ilerleme katmanının domain hata hiyerarşisi.
///
/// Hesap ve kütüphane hiyerarşilerinden AYRIDIR — her sözleşmenin kendi
/// hata şekli vardır ve biri diğerinin DTO'suyla ayrıştırılmaz.
sealed class RemoteReadingProgressException implements Exception {
  const RemoteReadingProgressException();

  String get message;
}

/// Saklı oturum yok — istek sunucuya HİÇ gönderilmedi. Anonim kullanıcı
/// `/api/progress` çağırmaz.
class ReadingProgressNotAuthenticatedException
    extends RemoteReadingProgressException {
  const ReadingProgressNotAuthenticatedException();

  @override
  String get message => 'Bu işlem için giriş yapmalısın.';
}

/// Sunucu sözleşmeye uygun, yapılandırılmış bir hata gövdesi döndü.
class ReadingProgressServerException extends RemoteReadingProgressException {
  const ReadingProgressServerException(this.error);

  final ReadingProgressErrorResponse error;

  @override
  String get message => error.errorDescription ?? 'İlerleme kaydedilemedi.';
}

/// Ağ/parse gibi sözleşme dışı arızalar.
class ReadingProgressUnexpectedException
    extends RemoteReadingProgressException {
  const ReadingProgressUnexpectedException(this.message);

  @override
  final String message;
}
