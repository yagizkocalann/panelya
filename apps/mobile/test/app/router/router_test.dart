import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelya_mobile/app/router/router.dart';
import 'package:panelya_mobile/app/theme/theme.dart';
import 'package:panelya_mobile/core/contracts/generated/generated.dart';
import 'package:panelya_mobile/features/discover/domain/discover_repository.dart';
import 'package:panelya_mobile/features/discover/presentation/discover_providers.dart';
import 'package:panelya_mobile/features/discover/presentation/discover_screen.dart';
import 'package:panelya_mobile/features/reader/domain/reader_repository.dart';
import 'package:panelya_mobile/features/reader/presentation/reader_providers.dart';
import 'package:panelya_mobile/features/reader/presentation/reader_screen.dart';
import 'package:panelya_mobile/features/series/domain/series_repository.dart';
import 'package:panelya_mobile/features/series/presentation/series_providers.dart';
import 'package:panelya_mobile/features/series/presentation/series_screen.dart';

/// Gerçek ağ çağrısı yapmayan sahte repository'ler: bu testler router'ın
/// yönlendirme/güvenli-düşüş davranışını doğrular, ekranların veri
/// durumlarını değil (bunlar zaten kendi widget testlerinde kapsanıyor).
/// `Completer` kullanılır — hiç tamamlanmayan bir `Future` `Timer`
/// yaratmaz, bu yüzden `pumpAndSettle` asılı kalmaz.
class _NeverResolvingDiscoverRepository implements DiscoverRepository {
  @override
  Future<CatalogResponse> fetchCatalog() => Completer<CatalogResponse>().future;
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

void main() {
  /// Gerçek `routerProvider` GoRouter'ını, üç ekranın da gerçek ağa
  /// çıkmadan (loading durumunda asılı kalarak) inşa edilebildiği bir
  /// `ProviderScope` içinde döndürür.
  ({GoRouter router, ProviderContainer container}) buildRouter() {
    final container = ProviderContainer(
      overrides: [
        discoverRepositoryProvider.overrideWithValue(
          _NeverResolvingDiscoverRepository(),
        ),
        seriesRepositoryProvider.overrideWithValue(
          _NeverResolvingSeriesRepository(),
        ),
        readerRepositoryProvider.overrideWithValue(
          _NeverResolvingReaderRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return (router: container.read(routerProvider), container: container);
  }

  Future<void> pumpRouter(
    WidgetTester tester,
    GoRouter router,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    // `pumpAndSettle` asla kullanılmaz: hedef ekranlar sahte repository'ler
    // yüzünden hep "yükleniyor" durumunda kalır ve `CircularProgressIndicator`
    // sonsuz döngülü bir animasyon çalıştırır — `pumpAndSettle` bu yüzden
    // asla ayarlanamaz (timeout). Sabit sayıda frame yeterli.
    await tester.pump();
    await tester.pump();
  }

  group('safe fallback (PLAN Görev 3: bilinmeyen/bozuk link -> keşif)', () {
    testWidgets('an unmatched path falls back to the discover screen via errorBuilder', (
      tester,
    ) async {
      final built = buildRouter();
      await pumpRouter(tester, built.router, built.container);

      built.router.go('/this/path/does/not/exist');
      await tester.pump();
      await tester.pump();

      // `go()` bir önceki (geçerli) konumu yığından tam olarak
      // temizlemeyebilir (bkz. go_router'ın hata sayfası davranışı); önemli
      // olan en az bir çalışan `DiscoverScreen`'in görünmesi ve crash
      // olmamasıdır — boş/kırık bir "not found" sayfası değil.
      expect(find.byType(DiscoverScreen), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a malformed custom-scheme link falls back to discover via redirect', (
      tester,
    ) async {
      final built = buildRouter();
      await pumpRouter(tester, built.router, built.container);

      built.router.go('panelya://series');
      await tester.pump();
      await tester.pump();

      expect(find.byType(DiscoverScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('panelya:// custom scheme redirect', () {
    testWidgets('bare scheme root navigates to discover', (tester) async {
      final built = buildRouter();
      await pumpRouter(tester, built.router, built.container);

      built.router.go('panelya://');
      await tester.pump();
      await tester.pump();

      expect(find.byType(DiscoverScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('series deep link navigates to the series screen', (
      tester,
    ) async {
      final built = buildRouter();
      await pumpRouter(tester, built.router, built.container);

      built.router.go('panelya://series/gece-vardiyasi');
      await tester.pump();
      await tester.pump();

      expect(find.byType(SeriesScreen), findsOneWidget);
      final screen = tester.widget<SeriesScreen>(find.byType(SeriesScreen));
      expect(screen.slug, 'gece-vardiyasi');
      expect(tester.takeException(), isNull);
    });

    testWidgets('episode deep link navigates to the reader screen', (
      tester,
    ) async {
      final built = buildRouter();
      await pumpRouter(tester, built.router, built.container);

      built.router.go('panelya://series/gece-vardiyasi/read/bolum-1');
      await tester.pump();
      await tester.pump();

      expect(find.byType(ReaderScreen), findsOneWidget);
      final screen = tester.widget<ReaderScreen>(find.byType(ReaderScreen));
      expect(screen.seriesSlug, 'gece-vardiyasi');
      expect(screen.episodeSlug, 'bolum-1');
      expect(tester.takeException(), isNull);
    });
  });
}
