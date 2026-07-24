import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/offline/domain/downloaded_episode.dart';
import 'package:panelya_mobile/features/offline/domain/offline_episode_content.dart';
import 'package:panelya_mobile/features/offline/domain/offline_episode_repository.dart';
import 'package:panelya_mobile/features/offline/presentation/episode_download_button.dart';
import 'package:panelya_mobile/features/offline/presentation/offline_providers.dart';

/// Bu dosyanın amacı bir regresyon: `EpisodeDownloadButton` (okuyucu, seri
/// ekranı satırı VE "İndirilenler" ekranının satırında paylaşılan tek
/// düğme) yalnız kendi `isEpisodeDownloadedProvider` anahtarını değil,
/// "İndirilenler" ekranının okuduğu global `downloadedEpisodesProvider`'ı
/// da tazelemeli — aksi halde o ekran, okuyucu/seri ekranından yapılan bir
/// indirme/silmeden SONRA bile eski (indirme/silme öncesi) önbellek
/// değerini göstermeye devam eder. Bu testler `downloads_screen.dart`
/// dosyasını HİÇ mount etmez; bunun yerine `downloadedEpisodesProvider`'ı
/// doğrudan izleyen minimal bir prob widget kullanır — böylece hangi
/// ekrandan tetiklendiğine bakılmaksızın düğmenin KENDİSİNİN doğru
/// invalidate ettiği doğrulanır.
class _InMemoryOfflineEpisodeRepository implements OfflineEpisodeRepository {
  final Set<String> _downloadedKeys = {};
  final Map<String, EpisodeManifestResponse> _manifests = {};

  String _key(String seriesSlug, String episodeSlug) =>
      '$seriesSlug/$episodeSlug';

  @override
  Future<bool> isDownloaded(String seriesSlug, String episodeSlug) async =>
      _downloadedKeys.contains(_key(seriesSlug, episodeSlug));

  @override
  Future<OfflineEpisodeContent?> loadDownloaded(
    String seriesSlug,
    String episodeSlug,
  ) async => null;

  @override
  Stream<double> downloadEpisode({
    required String apiOrigin,
    required EpisodeManifestResponse manifest,
  }) async* {
    yield 1.0;
    final key = _key(manifest.series.slug, manifest.episode.slug);
    _manifests[key] = manifest;
    _downloadedKeys.add(key);
  }

  @override
  Future<void> deleteDownload(String seriesSlug, String episodeSlug) async {
    _downloadedKeys.remove(_key(seriesSlug, episodeSlug));
  }

  @override
  Future<List<DownloadedEpisode>> listDownloaded() async {
    return [
      for (final entry in _manifests.entries)
        if (_downloadedKeys.contains(entry.key))
          DownloadedEpisode(
            seriesSlug: entry.value.series.slug,
            seriesTitle: entry.value.series.title,
            episodeSlug: entry.value.episode.slug,
            episodeNumber: entry.value.episode.number,
            episodeTitle: entry.value.episode.title,
            sizeBytes: 0,
          ),
    ];
  }
}

EpisodeManifestResponse _manifest() {
  return EpisodeManifestResponse(
    schemaVersion: '1.0',
    series: const EpisodeManifestSeriesRef(
      slug: 'gece-vardiyasi',
      title: 'Gece Vardiyası',
    ),
    episode: const Episode(
      slug: 'bolum-1',
      number: 1,
      title: 'Son Teslimat',
      publishedAt: '',
      readTime: '',
      panels: [],
    ),
    navigation: const EpisodeNavigation(previous: null, next: null),
  );
}

/// `downloadedEpisodesProvider`'ın o anki değerini düz metin olarak
/// gösteren prob widget (bkz. dosya doc yorumu).
class _DownloadedCountProbe extends ConsumerWidget {
  const _DownloadedCountProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodes = ref.watch(downloadedEpisodesProvider).asData?.value;
    return Text('probe:${episodes?.length ?? -1}');
  }
}

Widget _wrap(_InMemoryOfflineEpisodeRepository repository) {
  return ProviderScope(
    overrides: [offlineEpisodeRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Column(
          children: [
            const _DownloadedCountProbe(),
            EpisodeDownloadButton(
              seriesSlug: 'gece-vardiyasi',
              episodeSlug: 'bolum-1',
              resolveManifest: () => Future.value(_manifest()),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'indirme tamamlanınca downloadedEpisodesProvider da tazelenir (okuyucu/'
    'seri ekranından tetiklense bile "İndirilenler" ekranı güncel kalır)',
    (tester) async {
      final repository = _InMemoryOfflineEpisodeRepository();
      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      expect(find.text('probe:0'), findsOneWidget);

      await tester.tap(find.byTooltip('Bölümü indir'));
      await tester.pumpAndSettle();

      expect(find.text('probe:1'), findsOneWidget);
    },
  );

  testWidgets(
    'silme onaylanınca downloadedEpisodesProvider da tazelenir',
    (tester) async {
      final repository = _InMemoryOfflineEpisodeRepository();
      await repository.downloadEpisode(
        apiOrigin: 'https://example.invalid',
        manifest: _manifest(),
      ).drain<void>();

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      expect(find.text('probe:1'), findsOneWidget);

      await tester.tap(find.byTooltip('İndirildi · kaldırmak için dokunun'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();

      expect(find.text('probe:0'), findsOneWidget);
    },
  );
}
