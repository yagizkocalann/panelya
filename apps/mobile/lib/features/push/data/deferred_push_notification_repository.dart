import '../domain/push_notification_repository.dart';

/// Gerçek push repository'si HAZIR OLANA KADAR bekleyen, sonra ona devreden
/// sarmalayıcı.
///
/// Neden var: `Firebase.initializeApp()` ölçülen ortalamada **~405 ms**
/// sürüyor (Pixel 8 emülatörü, profile modu) ve eskiden `runApp`ten ÖNCE
/// await ediliyordu. Yani ilk kare, arayüzün hiç ihtiyaç duymadığı bir
/// başlatma için ~405 ms bekliyordu; karşılaştırma olarak
/// `SharedPreferences` + `path_provider` ikisi birlikte yalnız 6 ms.
///
/// Artık Firebase başlatması `runApp` ile PARALEL yürür. Bu sarmalayıcı,
/// başlatma bitmeden bir çağrı gelirse (ör. kullanıcı çok hızlı davranıp
/// Bildirimler ekranını açarsa ya da bir deep-link doğrudan oraya
/// götürürse) sessizce beklemesini sağlar — çağıranlar farkı görmez.
///
/// Firebase tipleri bilinçli olarak DIŞARIDA tutulmuştur: sınıf yalnız
/// [PushNotificationRepository] sözleşmesini bilir, bu yüzden eklenti
/// sınırına dokunmadan test edilebilir.
class DeferredPushNotificationRepository implements PushNotificationRepository {
  DeferredPushNotificationRepository(this._delegate);

  final Future<PushNotificationRepository> _delegate;

  @override
  Future<bool> requestPermission() async =>
      (await _delegate).requestPermission();

  @override
  Future<bool> hasPermission() async => (await _delegate).hasPermission();

  @override
  Future<void> subscribeToNewEpisodes() async =>
      (await _delegate).subscribeToNewEpisodes();

  @override
  Future<void> unsubscribeFromNewEpisodes() async =>
      (await _delegate).unsubscribeFromNewEpisodes();

  /// Bildirime dokunma akışı da beklemeye tabidir: soğuk başlangıçta
  /// bekleyen bir bildirim varsa (bkz. `getInitialMessage`) Firebase hazır
  /// olur olmaz yayınlanır, KAYBOLMAZ.
  @override
  Stream<Uri> get notificationTaps async* {
    yield* (await _delegate).notificationTaps;
  }
}
