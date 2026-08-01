import '../domain/account_exceptions.dart';

/// Bir yükleme hatasını kullanıcıya gösterilecek metne çevirir.
///
/// Sunucu sözleşmenin yapılandırılmış hata gövdesini döndürdüyse
/// ([AccountServerException]) SUNUCUNUN KENDİ AÇIKLAMASI gösterilir —
/// genel bir metinle örtülmez. Bu, "sahte başarı gösterme" ilkesinin
/// tamamlayıcısıdır: kullanıcı neyin neden çalışmadığını gerçekten görür
/// (ör. mobilde `scope: others` için bilinen 503 fail-closed durumu).
///
/// Yalnız sözleşme dışı/beklenmeyen hatalarda (ağ, parse) genel mesaja
/// düşülür.
String accountErrorMessage(Object error) {
  if (error is AccountRepositoryException) return error.message;
  return 'Beklenmeyen bir hata oluştu.';
}
