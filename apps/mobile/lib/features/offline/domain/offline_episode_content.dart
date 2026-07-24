import 'dart:io';

import '../../../core/contracts/generated/generated.dart';

/// Cihaza indirilmiş bir bölümün okuyucunun ihtiyaç duyduğu her şeyi bir
/// arada taşıyan sonucu: manifest (bkz. `EpisodeManifestResponse`, ağdan
/// gelenle AYNI şema) ve her panelin yerel görsel dosyası.
///
/// [panelImageFiles], [manifest.episode.panels] ile PARALEL bir listedir
/// (aynı uzunluk, aynı index sırası): panelin görseli yoksa (bkz.
/// `StoryPanel.image == null`) veya indirme sırasında kaydedilemediyse
/// (bkz. `FileSystemOfflineEpisodeRepository` doc yorumu) o index `null`
/// olur — okuyucu bu durumda mevcut görselsiz geri düşüşü (ton gradyanı)
/// kullanmaya devam eder, hiçbir zaman kırık bir dosya yolu göstermez.
class OfflineEpisodeContent {
  const OfflineEpisodeContent({
    required this.manifest,
    required this.panelImageFiles,
  });

  final EpisodeManifestResponse manifest;
  final List<File?> panelImageFiles;
}
