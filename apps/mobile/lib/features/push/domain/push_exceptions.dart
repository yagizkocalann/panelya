/// Push aboneliği ŞU AN değiştirilemediğinde fırlatılır (hem abone olma
/// hem aboneliği kaldırma) — bir programlama hatası değil, beklenen bir
/// çalışma zamanı durumudur.
///
/// Bilinen sebep (iOS): `subscribeToTopic`/`unsubscribeFromTopic` APNs
/// token'ı hazır olmadan çağrılırsa Firebase `apns-token-not-set`
/// fırlatır. Token, uygulama açılışında APNs kaydı tamamlandığında
/// ASENKRON gelir; simulator'da ise hiç gelmez (APNs simulator'da
/// çalışmaz).
///
/// Çağıranlar bunu DÜRÜSTÇE ele almalıdır: tercihi değişmiş gibi
/// göstermemeli, sahte başarı üretmemelidir (bkz. ADR-010).
class PushSubscriptionUnavailableException implements Exception {
  const PushSubscriptionUnavailableException();

  String get message =>
      'Bildirim tercihi şu an güncellenemedi. Lütfen daha sonra tekrar dene.';

  @override
  String toString() => 'PushSubscriptionUnavailableException: $message';
}
