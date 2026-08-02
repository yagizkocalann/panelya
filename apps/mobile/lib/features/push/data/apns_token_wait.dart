/// APNs token'ı sınırlı süre bekler (bkz.
/// `firebase_push_notification_repository.dart`).
///
/// iOS'ta APNs kaydı uygulama açılışından SONRA asenkron tamamlanır;
/// `bootstrap` abonelik çağrısını hemen yaptığı için ilk açılışta token
/// henüz gelmemiş olabilir. Bu fonksiyon token gelene kadar sınırlı sayıda
/// yoklar ve gelirse `true` döner.
///
/// Firebase tipleri bilinçli olarak DIŞARIDA tutulmuştur: [getToken] sade
/// bir `Future<String?>` üreticisidir, böylece bu mantık eklenti sınırına
/// dokunmadan test edilebilir.
///
/// Sınırlıdır: token hiç gelmezse (ör. simulator) sonsuza kadar beklemez,
/// [attempts] denemeden sonra `false` döner.
library;

import '../domain/push_exceptions.dart';

Future<bool> waitForApnsToken({
  required Future<String?> Function() getToken,
  int attempts = 8,
  Duration interval = const Duration(milliseconds: 250),
  Future<void> Function(Duration)? delay,
}) async {
  assert(attempts > 0, 'En az bir deneme yapılmalı.');
  final sleep = delay ?? Future<void>.delayed;

  for (var attempt = 0; attempt < attempts; attempt++) {
    // Token boş string dönebilir; bunu "hazır" saymak yanlış olur.
    final token = await getToken();
    if (token != null && token.isNotEmpty) return true;

    // Son denemeden sonra beklemek anlamsız — sonucu hemen bildir.
    if (attempt < attempts - 1) await sleep(interval);
  }
  return false;
}

/// [action]'ı çalıştırır; APNs token'ı henüz hazır değilse ([action]
/// [isApnsTokenNotSetError] doğru dönen bir hata fırlatırsa) [waitForToken]
/// ile SINIRLI süre bekleyip TAM OLARAK BİR KEZ daha dener (bkz.
/// `FirebasePushNotificationRepository._withApnsRetry` doc yorumu).
///
/// Üç dürüst sonuç mümkündür:
/// 1. İlk deneme başarılı → sessizce döner, [waitForToken] hiç çağrılmaz.
/// 2. Token GEÇ gelir ([waitForToken] `true` döner) → yeniden deneme
///    başarılı olur, sessizce döner (abonelik/kaldırma GERÇEKTEN olur).
/// 3. Token hiç gelmez YA DA yeniden deneme YİNE aynı hatayı verirse →
///    [PushSubscriptionUnavailableException] fırlatılır — sahte başarı
///    YOK, çağıran bunu yakalayıp dürüstçe göstermelidir.
///
/// [isApnsTokenNotSetError] dönen hatanın gerçekten "APNs token hazır
/// değil" durumu mu yoksa BAŞKA bir hata mı olduğunu ayırt eder; başka bir
/// hata ise hem ilk denemede hem yeniden denemede OLDUĞU GİBİ (sarmalanmadan)
/// yeniden fırlatılır.
///
/// Firebase tipleri bilinçli olarak DIŞARIDA tutulmuştur (bkz.
/// [waitForApnsToken] doc yorumu) — bu fonksiyon yalnız hata tahmin edici
/// bir callback bilir, bu yüzden eklenti sınırına dokunmadan test edilebilir.
Future<void> withApnsRetry({
  required Future<void> Function() action,
  required bool Function(Object error) isApnsTokenNotSetError,
  required Future<bool> Function() waitForToken,
}) async {
  try {
    await action();
  } on Object catch (error) {
    if (!isApnsTokenNotSetError(error)) rethrow;

    final ready = await waitForToken();
    if (!ready) throw const PushSubscriptionUnavailableException();

    try {
      await action();
    } on Object catch (retryError) {
      if (!isApnsTokenNotSetError(retryError)) rethrow;
      throw const PushSubscriptionUnavailableException();
    }
  }
}
