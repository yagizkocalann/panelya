import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/catalog/presentation/catalog_screen.dart';
import '../../features/discover/presentation/discover_screen.dart';
import '../../features/discovery/presentation/new_episodes_screen.dart';
import '../../features/discovery/presentation/new_series_screen.dart';
import '../../features/reader/presentation/reader_screen.dart';
import '../../features/series/presentation/series_screen.dart';
import 'deep_link.dart';
import 'route_args.dart';

/// Deep-link-hazır rotalar (bkz. docs/mobile-handoff.md İlk mobil kapsam #5
/// ve "Güncel web bilgi mimarisinin Flutter karşılığı"):
/// - `/` — Editorial keşif ana sayfası
/// - `/catalog` — Tam katalog, arama ve tür filtresi
/// - `/new-series` — Yeni Seriler'in tam listesi
/// - `/new-episodes` — Yeni Eklenen Bölümler'in tam listesi
/// - `/series/:slug` — Seri detay
/// - `/series/:slug/read/:episodeSlug` — Okuyucu
///
/// Auth, kütüphane, Studio rotaları kapsam dışıdır (bkz. PLAN Sınırlar).
///
/// Güvenli düşüş (PLAN Görev 3): `panelya://` custom scheme linkleri
/// [redirect] içinde [resolveCustomSchemeRoute] ile bilinen rotalardan birine
/// çevrilir (o fonksiyon hiçbir zaman null dönmez; bugün yalnız `/`,
/// `/series/:slug` ve `/series/:slug/read/:episodeSlug` şemaları tanır —
/// `/catalog`, `/new-series`, `/new-episodes` uygulama-içi navigasyon
/// hedefleridir, harici deep-link şeması taşımaz). Bu rotaların dışında
/// kalan her şey — bozuk path, bilinmeyen scheme, eksik segment — hiçbir
/// GoRoute ile eşleşmez ve [errorBuilder] devreye girer; o da kesif
/// ekranını (boş/hata ekranı değil, çalışan `DiscoverScreen`) gösterir.
/// Böylece hem redirect hem errorBuilder aynı ilkeyi uygular: bilinmeyen/
/// bozuk link asla crash veya boş ekrana değil, keşfe düşer.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final uri = state.uri;
      if (uri.scheme == 'panelya') {
        return resolveCustomSchemeRoute(uri);
      }
      // Web-benzeri path'ler (Universal Links/App Links, henüz yok):
      // production domain kararı verilince burada
      // `mapWebPathToMobileRoute` ile aynı çevrim uygulanacak (bkz.
      // apps/mobile/README.md "Gelecek adım").
      return null;
    },
    errorBuilder: (context, state) => const DiscoverScreen(),
    routes: [
      GoRoute(path: '/', builder: (context, state) => const DiscoverScreen()),
      GoRoute(
        path: '/catalog',
        builder: (context, state) {
          // Ana sayfadaki açılır tür dizininden (bkz. `GenreDisclosure`)
          // `CatalogRouteArgs` ile bir tür önceden seçili gelebilir;
          // `extra` beklenmeyen bir tipteyse (örn. doğrudan `/catalog`
          // linkine gidildiyse) sessizce `null`'a düşülür — tür filtresi
          // açık kalır, katalog yine tam çalışır durumda gösterilir.
          final extra = state.extra;
          final initialGenre = extra is CatalogRouteArgs
              ? extra.initialGenre
              : null;
          return CatalogScreen(initialGenre: initialGenre);
        },
      ),
      GoRoute(
        path: '/new-series',
        builder: (context, state) => const NewSeriesScreen(),
      ),
      GoRoute(
        path: '/new-episodes',
        builder: (context, state) => const NewEpisodesScreen(),
      ),
      GoRoute(
        path: '/series/:slug',
        builder: (context, state) =>
            SeriesScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/series/:slug/read/:episodeSlug',
        builder: (context, state) => ReaderScreen(
          seriesSlug: state.pathParameters['slug']!,
          episodeSlug: state.pathParameters['episodeSlug']!,
        ),
      ),
    ],
  );
});
