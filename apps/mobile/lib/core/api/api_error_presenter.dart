import 'api_exception.dart';

/// [ApiException] alt tiplerini kullanıcıya gösterilecek Türkçe, kısa bir
/// mesaja çevirir. Ekranlar hata gövdesini veya stack trace'i doğrudan
/// göstermez.
String describeApiException(ApiException exception) {
  return switch (exception) {
    NetworkException() =>
      'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.',
    HttpStatusException(isNotFound: true) => 'Aradığınız içerik bulunamadı.',
    HttpStatusException(isServerError: true) =>
      'Sunucuda geçici bir sorun oluştu. Lütfen tekrar deneyin.',
    HttpStatusException() => 'İstek tamamlanamadı. Lütfen tekrar deneyin.',
    ParseException() =>
      'Sunucudan beklenmeyen bir yanıt geldi. Lütfen tekrar deneyin.',
    SchemaMismatchException() =>
      'Uygulama sürümünüz güncel değil; lütfen uygulamayı güncelleyin.',
  };
}
