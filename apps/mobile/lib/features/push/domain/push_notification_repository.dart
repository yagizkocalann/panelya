/// Push bildirimi (FCM) sözleşmesi (bkz. docs/local-gap-backlog.md P2
/// madde 3 — "Deep link, çevrimdışı okuma ve push bildirimleri",
/// docs/mobile-handoff.md "FCM topic sınırı").
///
/// Yeni bölüm duyuruları herkese açık bilgidir (hesap/giriş gerektirmez):
/// backend cihaz token'ı toplamaz/saklamaz, tek bir FCM konu (`topic`)
/// mesajı gönderir (bkz. [newEpisodesPushTopic]). Mobil istemci yalnız bu
/// sabit konuya abone olur/olmaktan çıkar — token yönetimi, yeniden abone
/// olma ve iletim tamamen Firebase SDK sınırında kalır.
abstract class PushNotificationRepository {
  /// Kullanıcıdan bildirim izni ister (iOS: sistem izin diyaloğu; Android
  /// 13+: `POST_NOTIFICATIONS` çalışma zamanı izni) ve izin verilip
  /// verilmediğini döner. Bu çağrı asla hata fırlatmaz.
  Future<bool> requestPermission();

  /// Daha önce izin isteği yapılmadan/OS ayarlarından mevcut izin
  /// durumunu (yeniden bir sistem diyaloğu göstermeden) sorgular. Ayar
  /// ekranının, kullanıcı OS ayarlarından izni geri almış olsa bile
  /// güncel durumu göstermesi için kullanılır.
  Future<bool> hasPermission();

  /// [newEpisodesPushTopic] konusuna abone olur (bkz. sınıf doc yorumu).
  /// Yalnız izin verilmişken çağrılmalıdır (bkz. docs/mobile-handoff.md
  /// "Bildirim izni verilmeden topic aboneliği yapılmaz").
  Future<void> subscribeToNewEpisodes();

  /// [newEpisodesPushTopic] konusundan aboneliği kaldırır. İzin durumundan
  /// bağımsız her zaman güvenle çağrılabilir (hiç abone olunmamışsa
  /// no-op).
  Future<void> unsubscribeFromNewEpisodes();

  /// Uygulama arka plandayken/kapalıyken bir bildirime dokunulduğunda
  /// (veya soğuk başlangıçta zaten bekleyen bir bildirim varsa) o
  /// bildirimin veri yükünden çözülen deep-link URI'sini yayınlar (bkz.
  /// [deepLinkDataKey]). Uygulama ÖN PLANDAYKEN gelen bildirimler bu
  /// stream'e YANSIMAZ (bkz. sınıf doc yorumu — v1 kapsamı yalnız arka
  /// plan/kapalı durumdaki dokunma akışını kapsar; ön planda sistem bandı
  /// göstermek `flutter_local_notifications` gerektirir, ayrı bir iş).
  Stream<Uri> get notificationTaps;
}

/// Backend'in `dispatchPushBroadcast`'in gönderdiği sabit FCM konusu (bkz.
/// `app/lib/push-notifications.ts` -> `NEW_EPISODES_PUSH_TOPIC`). Bu
/// değer API'den tahmin edilmez, kullanıcı/seri kimliği taşımaz.
const newEpisodesPushTopic = 'panelya-new-episodes';

/// Backend'in FCM mesajının `data` yüküne koyduğu alan adı — değeri
/// `panelya://series/<slug>/read/<episodeSlug>` gibi
/// `app/router/deep_link.dart`nin zaten çözebildiği bir `panelya://`
/// URI'si olur.
const deepLinkDataKey = 'deepLink';
