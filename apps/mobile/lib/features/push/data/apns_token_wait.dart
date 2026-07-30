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
