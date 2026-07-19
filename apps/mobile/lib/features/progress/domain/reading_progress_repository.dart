import 'reading_progress.dart';

/// Cihaz-yerel okuma ilerlemesi verisine erişim sözleşmesi (Novel-Project'in
/// repository-interface deseni, bkz. docs/mobile-handoff.md "Başlangıç
/// ilkesi"). Ekranlar bu arayüzü yalnız Riverpod provider'ları üzerinden
/// kullanır; hiçbir ekran `SharedPreferences`'a (veya başka bir depolama
/// API'sine) doğrudan dokunmaz.
///
/// Kapsam sınırı: bu, auth'lu `/api/progress` ile AYNI ŞEY DEĞİLDİR. Bu
/// kayıt yalnız cihazda yaşar, hesap gerektirmez ve hiçbir API çağrısı
/// yapmaz.
///
/// Okuma metotları senkrondur: [SharedPreferences] örneği bootstrap
/// sırasında bir kez `await`lenir (bkz. `app/bootstrap/bootstrap.dart`),
/// sonrasında okuma/yazma bellek-içi önbellek üzerinden anında çalışır; bu
/// yüzden ekranlarda `AsyncValue` sarmalayıcısına gerek yoktur.
abstract class LocalReadingProgressRepository {
  /// Belirli bir seri için kayıtlı ilerleme; kayıt yoksa `null`.
  ReadingProgress? findBySeries(String seriesSlug);

  /// Tüm serilerdeki en son güncellenen kayıt (keşif şeridi için); hiç
  /// kayıt yoksa `null`.
  ReadingProgress? findMostRecent();

  /// Okuyucuda bir bölüm açıldığında çağrılır: `seriesSlug -> (episodeSlug,
  /// açılma zamanı)` kaydını üstüne yazar ve `completed`'ı sıfırlar (bu
  /// bölüm henüz sonuna kadar okunmadı).
  Future<void> recordEpisodeOpened({
    required String seriesSlug,
    required String seriesTitle,
    required String episodeSlug,
    required int episodeNumber,
  });

  /// Okuyucuda bölüm sonuna scroll edildiğinde çağrılır. Sonraki bölüm
  /// varsa ([nextEpisodeSlug]/[nextEpisodeNumber] doluysa) devam hedefi o
  /// olur (kayıt güncellenir, `completed: false`); yoksa kayıt biten
  /// bölümde kalır ve `completed: true` işaretlenir.
  Future<void> recordEpisodeCompleted({
    required String seriesSlug,
    required String seriesTitle,
    required String episodeSlug,
    required int episodeNumber,
    String? nextEpisodeSlug,
    int? nextEpisodeNumber,
  });
}
