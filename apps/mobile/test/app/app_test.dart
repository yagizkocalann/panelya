import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelya_mobile/app/app.dart';
import 'package:panelya_mobile/app/router/router.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/discover/domain/discover_repository.dart';
import 'package:panelya_mobile/features/discover/presentation/discover_providers.dart';
import 'package:panelya_mobile/features/discovery/domain/discovery_repository.dart';
import 'package:panelya_mobile/features/discovery/presentation/discovery_providers.dart';
import 'package:panelya_mobile/features/offline/domain/downloaded_episode.dart';
import 'package:panelya_mobile/features/offline/domain/offline_episode_content.dart';
import 'package:panelya_mobile/features/offline/domain/offline_episode_repository.dart';
import 'package:panelya_mobile/features/offline/presentation/offline_providers.dart';
import 'package:panelya_mobile/features/push/domain/push_notification_repository.dart';
import 'package:panelya_mobile/features/push/presentation/push_providers.dart';
import 'package:panelya_mobile/features/reader/domain/reader_repository.dart';
import 'package:panelya_mobile/features/reader/presentation/reader_providers.dart';
import 'package:panelya_mobile/features/series/domain/series_repository.dart';
import 'package:panelya_mobile/features/series/presentation/series_providers.dart';

/// Bu dosyanın amacı: `PanelyaApp`nin kök seviyede kurduğu tek gerçek
/// mantığı — arka planda/kapalıyken dokunulan bir push bildiriminin
/// deep-link URI'sini go_router'a yönlendirmesi (bkz. `app/app.dart`daki
/// `ref.listen(pendingNotificationRouteProvider, ...)`) — doğrulamak.
/// Diğer her şey (ekranların kendi içeriği, veri durumları) zaten kendi
/// widget testlerinde kapsanıyor; bu yüzden `router_test.dart`daki ile
/// AYNI "hiç tamamlanmayan sahte repository" deseni kullanılıyor — ekranlar
/// hep yükleniyor durumunda kalır, testler yalnız ROTA'yı doğrular.
class _NeverResolvingDiscoverRepository implements DiscoverRepository {
  @override
  Future<CatalogResponse> fetchCatalog() => Completer<CatalogResponse>().future;
}

class _NeverResolvingDiscoveryRepository implements DiscoveryRepository {
  @override
  Future<DiscoveryResponse> fetchDiscovery() =>
      Completer<DiscoveryResponse>().future;
}

class _NeverResolvingSeriesRepository implements SeriesRepository {
  @override
  Future<SeriesDetailResponse> fetchSeriesDetail(String slug) =>
      Completer<SeriesDetailResponse>().future;
}

class _NeverResolvingReaderRepository implements ReaderRepository {
  @override
  Future<EpisodeManifestResponse> fetchEpisodeManifest(
    String seriesSlug,
    String episodeSlug,
  ) => Completer<EpisodeManifestResponse>().future;
}

class _NeverResolvingOfflineEpisodeRepository
    implements OfflineEpisodeRepository {
  @override
  Future<bool> isDownloaded(String seriesSlug, String episodeSlug) =>
      Completer<bool>().future;

  @override
  Future<OfflineEpisodeContent?> loadDownloaded(
    String seriesSlug,
    String episodeSlug,
  ) => Completer<OfflineEpisodeContent?>().future;

  @override
  Stream<double> downloadEpisode({
    required String apiOrigin,
    required EpisodeManifestResponse manifest,
  }) => const Stream.empty();

  @override
  Future<void> deleteDownload(String seriesSlug, String episodeSlug) =>
      Completer<void>().future;

  @override
  Future<List<DownloadedEpisode>> listDownloaded() =>
      Completer<List<DownloadedEpisode>>().future;
}

/// Testin push bildirimi tarafını kontrol edebilmesi için:
/// `notificationTaps`'e istediği anda bir URI enjekte edebilir.
class _FakePushNotificationRepository implements PushNotificationRepository {
  final _controller = StreamController<Uri>.broadcast();

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> subscribeToNewEpisodes() async {}

  @override
  Future<void> unsubscribeFromNewEpisodes() async {}

  @override
  Stream<Uri> get notificationTaps => _controller.stream;

  void emitTap(Uri uri) => _controller.add(uri);
}

void main() {
  testWidgets(
    'arka planda dokunulan bir push bildirimi go_router\'ı ilgili '
    'bölüm rotasına götürür (panelya:// deep-link şeması ile aynı çözüm)',
    (tester) async {
      final pushRepository = _FakePushNotificationRepository();
      final container = ProviderContainer(
        overrides: [
          discoverRepositoryProvider.overrideWithValue(
            _NeverResolvingDiscoverRepository(),
          ),
          discoveryRepositoryProvider.overrideWithValue(
            _NeverResolvingDiscoveryRepository(),
          ),
          seriesRepositoryProvider.overrideWithValue(
            _NeverResolvingSeriesRepository(),
          ),
          readerRepositoryProvider.overrideWithValue(
            _NeverResolvingReaderRepository(),
          ),
          offlineEpisodeRepositoryProvider.overrideWithValue(
            _NeverResolvingOfflineEpisodeRepository(),
          ),
          pushNotificationRepositoryProvider.overrideWithValue(
            pushRepository,
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PanelyaApp(),
        ),
      );
      await tester.pump();
      await tester.pump();

      final router = container.read(routerProvider);
      expect(router.routeInformationProvider.value.uri.path, '/');

      pushRepository.emitTap(
        Uri.parse('panelya://series/gece-vardiyasi/read/bolum-3'),
      );
      await tester.pump();
      await tester.pump();

      expect(
        router.routeInformationProvider.value.uri.path,
        '/series/gece-vardiyasi/read/bolum-3',
      );
    },
  );
}
