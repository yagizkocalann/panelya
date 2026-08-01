/// [OfflineEpisodeRepository.listDownloaded] sonucundaki tek bir kayıt:
/// cihaza indirilmiş bir bölümün "İndirilenler" ekranında (bkz.
/// `downloads_screen.dart`) gösterilmesi için yeterli özet bilgi.
class DownloadedEpisode {
  const DownloadedEpisode({
    required this.seriesSlug,
    required this.seriesTitle,
    required this.episodeSlug,
    required this.episodeNumber,
    required this.episodeTitle,
    required this.sizeBytes,
  });

  final String seriesSlug;
  final String seriesTitle;
  final String episodeSlug;
  final int episodeNumber;
  final String episodeTitle;

  /// Manifest + tüm panel görsellerinin toplam bayt sayısı (disk üzerinde
  /// kapladığı gerçek yer — kullanıcıya "İndirilenler" ekranında ne kadar
  /// depolama kullanıldığını göstermek için).
  final int sizeBytes;
}
