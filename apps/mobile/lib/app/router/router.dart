import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/discover/presentation/discover_screen.dart';
import '../../features/reader/presentation/reader_screen.dart';
import '../../features/series/presentation/series_screen.dart';

/// Deep-link-hazır rotalar (bkz. docs/mobile-handoff.md İlk mobil kapsam #5):
/// - `/` — Keşif/katalog
/// - `/series/:slug` — Seri detay
/// - `/series/:slug/read/:episodeSlug` — Okuyucu
///
/// Faz 1'de yalnız bu üç rota vardır; auth, kütüphane, Studio rotaları
/// kapsam dışıdır (bkz. PLAN Sınırlar).
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
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
