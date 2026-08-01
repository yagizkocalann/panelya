import '../../../core/contracts/generated/generated.dart';
import 'downloaded_episode.dart';
import 'offline_episode_content.dart';

/// Cihaz-yerel çevrimdışı bölüm indirme sözleşmesi (bkz.
/// docs/local-gap-backlog.md P2 madde 3 — "Deep link, çevrimdışı okuma ve
/// push bildirimleri"; mobile-handoff.md "Çevrimdışı okuma ... sonraki
/// mobil fazlarda kalır").
///
/// [LocalReadingProgressRepository] (bkz. `features/progress/`) ile AYNI
/// kapsam sınırını taşır: bu, hesap/backend session GEREKTİRMEZ, yalnız
/// cihazda yaşar ve hiçbir API çağrısı yapmaz — yalnız zaten yayınlanmış
/// panel görsellerini indirip yerel dosyaya yazar.
///
/// Ekranlar bu arayüzü yalnız Riverpod provider'ları üzerinden kullanır
/// (bkz. `presentation/offline_providers.dart`); hiçbir ekran `dart:io`'ya
/// veya `path_provider`'a doğrudan dokunmaz.
abstract class OfflineEpisodeRepository {
  /// Bu bölüm daha önce başarıyla indirilmiş mi (bkz. [downloadEpisode]
  /// doc yorumu — yalnız TÜM paneller indirildikten sonra `true` olur,
  /// yarım kalan bir indirme asla `true` döndürmez).
  Future<bool> isDownloaded(String seriesSlug, String episodeSlug);

  /// İndirilmiş bölümün manifestini ve panel görsellerinin yerel
  /// dosyalarını döner; indirilmemişse `null`.
  Future<OfflineEpisodeContent?> loadDownloaded(
    String seriesSlug,
    String episodeSlug,
  );

  /// [manifest]'teki tüm panel görsellerini [apiOrigin] üzerinden indirip
  /// cihaza kaydeder. Dönen `Stream<double>`, `0.0`-`1.0` arası ilerleme
  /// yüzdesini yayınlar (son değer her zaman `1.0`'dır).
  ///
  /// Ara adımlarda bir görsel indirme hatası oluşursa stream bir hata
  /// olayıyla kapanır ve o ana kadar yazılmış kısmi dosyalar SİLİNİR — bu
  /// bölüm için [isDownloaded] `false` kalmaya devam eder (yarım/bozuk bir
  /// "indirilmiş" durumu asla görünmez).
  Stream<double> downloadEpisode({
    required String apiOrigin,
    required EpisodeManifestResponse manifest,
  });

  /// Daha önce indirilmiş bir bölümü ve tüm yerel dosyalarını siler.
  /// Bölüm zaten indirilmemişse sessizce hiçbir şey yapmaz.
  Future<void> deleteDownload(String seriesSlug, String episodeSlug);

  /// Cihaza indirilmiş TÜM bölümleri (tüm seriler dahil) döner — bkz.
  /// "İndirilenler" ekranı (`downloads_screen.dart`). Seri adına, sonra
  /// bölüm numarasına göre sıralı gelir. Hiç indirme yoksa boş liste
  /// döner (asla `null`/hata değil).
  Future<List<DownloadedEpisode>> listDownloaded();
}
