import 'dart:async';

import '../domain/remote_reading_progress_exceptions.dart';
import '../domain/remote_reading_progress_repository.dart';

/// Okuyucudaki ilerleme yazımlarını SINIRLAR ve uzak/yerel sınırını
/// yönetir.
///
/// NEDEN VAR: okuyucu scroll'u her pikselde bir yüzde üretir; bunların
/// hepsini `POST /api/progress`e çevirmek sunucuyu ve pili gereksiz yere
/// yorar. Bu sınıf iki kural uygular:
///
/// 1. **Anlamlı değişiklik eşiği** ([minPercentDelta]): son GÖNDERİLEN
///    yüzdeden en az bu kadar farklı olmayan güncellemeler yok sayılır.
/// 2. **Debounce** ([debounce]): eşiği geçen güncellemeler hemen değil,
///    kısa bir sessizlik sonrası tek bir istekle gönderilir.
///
/// İSTİSNA — `percent == 100`: bölüm sonu KESİN yazılır. Ne eşiğe ne
/// debounce'a takılır; bekleyen zamanlayıcı iptal edilip hemen gönderilir.
/// (Sözleşme: `100`, KAYITLI BÖLÜMÜN tamamlandığı anlamına gelir. Sonraki
/// bölüm sunucuya otomatik `0` diye YAZILMAZ.)
///
/// GÜVENLİ KAPANIŞ ([flush]): okuyucu kapanırken bekleyen bir yazım varsa
/// atılmaz, hemen gönderilir. `dispose` zamanlayıcıyı temizler.
///
/// DÜRÜSTLÜK: uzak yazım başarısız olursa okuma ENGELLENMEZ (hata yutulur,
/// kullanıcı okumaya devam eder) ama başarılıymış gibi de GÖSTERİLMEZ —
/// [lastSyncFailed] ve [onRemoteSuccess] çağıranın gerçek durumu bilmesini
/// sağlar. Başarılı bir uzak yanıt [onRemoteSuccess] ile yerel cache'e
/// aynalanabilir.
class ReadingProgressSync {
  ReadingProgressSync({
    required this._remote,
    this.debounce = const Duration(seconds: 3),
    this.minPercentDelta = 5,
    this.onRemoteSuccess,
  });

  final RemoteReadingProgressRepository _remote;
  final Duration debounce;
  final int minPercentDelta;

  /// Başarılı bir uzak yazımdan sonra çağrılır — yerel cache aynalaması
  /// için. Uzak yazım BAŞARISIZSA çağrılmaz.
  final Future<void> Function(
    String seriesSlug,
    String episodeSlug,
    int percent,
  )?
  onRemoteSuccess;

  Timer? _timer;
  _PendingWrite? _pending;
  int? _lastSentPercent;
  String? _lastSentEpisode;

  /// Son uzak yazımın başarısız olduğunu bildirir. Çağıran bunu "senkron
  /// edilemedi" olarak gösterebilir; sahte başarı üretmez.
  bool get lastSyncFailed => _lastSyncFailed;
  bool _lastSyncFailed = false;

  /// Bekleyen (henüz gönderilmemiş) bir yazım var mı — test/teşhis için.
  bool get hasPendingWrite => _pending != null;

  /// Okuyucudan gelen ilerleme bildirimi.
  void report({
    required String seriesSlug,
    required String episodeSlug,
    required int percent,
  }) {
    final clamped = percent.clamp(0, 100);

    // Bölüm sonu: eşiği ve debounce'ı ATLAYARAK kesin yaz.
    if (clamped == 100) {
      _timer?.cancel();
      _timer = null;
      _pending = _PendingWrite(seriesSlug, episodeSlug, 100);
      unawaited(_send());
      return;
    }

    // Aynı bölümde anlamsız küçük değişiklikleri ele.
    if (_lastSentEpisode == episodeSlug &&
        _lastSentPercent != null &&
        (clamped - _lastSentPercent!).abs() < minPercentDelta) {
      return;
    }

    _pending = _PendingWrite(seriesSlug, episodeSlug, clamped);
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(_send()));
  }

  /// Bekleyen yazımı HEMEN gönderir (yaşam döngüsü kapanışı).
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_pending == null) return;
    await _send();
  }

  Future<void> _send() async {
    final write = _pending;
    if (write == null) return;
    _pending = null;

    try {
      await _remote.upsertProgress(
        seriesSlug: write.seriesSlug,
        episodeSlug: write.episodeSlug,
        percent: write.percent,
      );
      _lastSentPercent = write.percent;
      _lastSentEpisode = write.episodeSlug;
      _lastSyncFailed = false;
      await onRemoteSuccess?.call(
        write.seriesSlug,
        write.episodeSlug,
        write.percent,
      );
    } on ReadingProgressNotAuthenticatedException {
      // Anonim kullanıcı: sunucuya istek yapılmadı, sessizce geçilir.
      // Yerel kayıt zaten ayrı yoldan tutuluyor.
      _lastSyncFailed = false;
    } on RemoteReadingProgressException {
      // Uzak yazım başarısız: okuma ENGELLENMEZ ama başarılı da SAYILMAZ.
      _lastSyncFailed = true;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

class _PendingWrite {
  const _PendingWrite(this.seriesSlug, this.episodeSlug, this.percent);

  final String seriesSlug;
  final String episodeSlug;
  final int percent;
}
