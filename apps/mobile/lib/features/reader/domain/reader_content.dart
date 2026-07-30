import 'dart:io';

import '../../../core/contracts/generated/generated.dart';

/// Okuyucunun göstereceği içerik: ya canlı ağ manifesti (görseller
/// `apiOrigin`e göre çözülür) ya da daha önce indirilmiş bir bölüm
/// (görseller yerel dosyadan okunur, ağ hiç gerekmez — bkz.
/// `features/offline/`).
///
/// [offlinePanelImageFiles] yalnız [isOffline] `true` iken doludur ve
/// [manifest.episode.panels] ile PARALEL bir listedir (bkz.
/// `OfflineEpisodeContent` doc yorumu — aynı null-index kuralı geçerlidir).
class ReaderContent {
  const ReaderContent.online(this.manifest) : offlinePanelImageFiles = null;

  const ReaderContent.offline(this.manifest, List<File?> panelImageFiles)
    : offlinePanelImageFiles = panelImageFiles;

  final EpisodeManifestResponse manifest;
  final List<File?>? offlinePanelImageFiles;

  bool get isOffline => offlinePanelImageFiles != null;
}
