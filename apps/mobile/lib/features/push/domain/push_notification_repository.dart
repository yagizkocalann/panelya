/// Push bildirimi (FCM) sözleşmesi (bkz. docs/local-gap-backlog.md P2
/// madde 3 — "Deep link, çevrimdışı okuma ve push bildirimleri").
///
/// Bu arayüzün arkasında bugün TEK gerçek implementasyon var
/// (`FirebasePushNotificationRepository`, bkz. `data/`) — backend tarafı
/// (cihaz token'ını kaydetme uç noktası, yeni bölüm yayınlandığında FCM'e
/// gönderim) henüz AYRI bir iş olarak bekliyor (bkz. proje notu: "şimdilik
/// sadece mobil, backend'i not al"). Bu ara dönemde gerçek teslimat yalnız
/// Firebase Console'un "Send test message" özelliğiyle [getToken]'dan
/// alınan token'a elle gönderilerek doğrulanabilir.
abstract class PushNotificationRepository {
  /// Kullanıcıdan bildirim izni ister (iOS: sistem izin diyaloğu; Android
  /// 13+: `POST_NOTIFICATIONS` çalışma zamanı izni). Reddedilirse push hiç
  /// gelmez ama uygulama normal çalışmaya devam eder — bu çağrı asla hata
  /// fırlatmaz.
  Future<void> requestPermission();

  /// Bu cihazın FCM kayıt token'ı (backend'in bu cihaza mesaj
  /// gönderebilmesi için ihtiyaç duyacağı kimlik). İzin verilmemişse veya
  /// token henüz hazır değilse `null` döner.
  Future<String?> getToken();

  /// Uygulama arka plandayken/kapalıyken bir bildirime dokunulduğunda
  /// (veya soğuk başlangıçta zaten bekleyen bir bildirim varsa) o
  /// bildirimin veri yükünden çözülen deep-link URI'sini yayınlar (bkz.
  /// [deepLinkDataKey] — backend'in mesaj veri yüküne koyması gereken
  /// alan). Uygulama ÖN PLANDAYKEN gelen bildirimler bu stream'e YANSIMAZ
  /// (bkz. sınıf doc yorumu — v1 kapsamı yalnız arka plan/kapalı
  /// durumdaki dokunma akışını kapsar; ön planda sistem bandı göstermek
  /// `flutter_local_notifications` gerektirir, ayrı bir iş).
  Stream<Uri> get notificationTaps;
}

/// Backend'in (ileride) FCM mesajının `data` yüküne koyması GEREKEN alan
/// adı — değeri `panelya://series/<slug>/read/<episodeSlug>` gibi
/// `app/router/deep_link.dart`nin zaten çözebildiği bir `panelya://`
/// URI'si olmalı.
const deepLinkDataKey = 'deepLink';
