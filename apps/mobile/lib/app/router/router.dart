import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/discover/presentation/discover_screen.dart';
import '../../features/reader/presentation/reader_screen.dart';
import '../../features/series/presentation/series_screen.dart';
import 'deep_link.dart';

/// Deep-link-hazır rotalar (bkz. docs/mobile-handoff.md İlk mobil kapsam #5):
/// - `/` — Keşif/katalog
/// - `/series/:slug` — Seri detay
/// - `/series/:slug/read/:episodeSlug` — Okuyucu
///
/// Faz 1'de yalnız bu üç rota vardır; auth, kütüphane, Studio rotaları
/// kapsam dışıdır (bkz. PLAN Sınırlar).
///
/// Güvenli düşüş (PLAN Görev 3): `panelya://` custom scheme linkleri
/// [redirect] içinde [resolveCustomSchemeRoute] ile bu üç rotadan birine
/// çevrilir (o fonksiyon hiçbir zaman null dönmez). Bu üç rotanın dışında
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
