import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/profile_screen.dart';
import '../../features/account/presentation/security_screen.dart';
import '../../core/config/account_management_feature_config.dart';
import '../../features/account/presentation/blocked_accounts_screen.dart';
import '../../features/account/presentation/delete_account_screen.dart';
import '../../features/account/presentation/sessions_screen.dart';
import '../../features/auth/presentation/account_screen.dart';
import '../../features/catalog/presentation/catalog_screen.dart';
import '../../features/discover/presentation/discover_screen.dart';
import '../../features/discovery/presentation/new_episodes_screen.dart';
import '../../features/discovery/presentation/new_series_screen.dart';
import '../../features/offline/presentation/downloads_screen.dart';
import '../../features/push/presentation/notification_settings_screen.dart';
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
/// - `/downloads` — İndirilenler (cihaz-yerel çevrimdışı bölümler; bkz.
///   docs/local-gap-backlog.md P2 madde 3, `features/offline/`). Web'de
///   karşılığı YOK — mobile-only, bu yüzden `mapWebPathToMobileRoute`de
///   bilerek bir eşlemesi bulunmuyor.
/// - `/account` — Hesabım (bkz. `features/auth/`). Kimliği doğrulanmışken
///   gerçek içeriği (ADR-047) `features/account/`deki `AccountHomeScreen`ye
///   devreder. Yalnız `AuthFeatureConfig.enabled` açıkken
///   `discover_screen.dart`daki giriş noktasından erişilebilir;
///   `/downloads` ile aynı gerekçeyle mobile-only, `mapWebPathToMobileRoute`de
///   eşlemesi yok.
/// - `/account/profile` — Profil (bkz. `features/account/`, ADR-047):
///   görünen ad düzenleme. Yalnız `AccountHomeScreen`in gezinme
///   satırından erişilebilir; `/account` ile aynı gerekçeyle mobile-only,
///   `resolveCustomSchemeRoute`de tanınmaz.
/// - `/account/security` — E-posta ve şifre (bkz. `features/account/`,
///   ADR-047): sağlayıcıya göre (Database/Google) e-posta değiştirme ve
///   şifre sıfırlama e-postası VEYA yalnız açıklayıcı metin gösterir.
///   `/account/profile` ile aynı gerekçeyle mobile-only.
/// - `/account/sessions` — Aktif oturumlar (bkz. `features/account/`,
///   ADR-047): oturum listesi, mevcut cihaz rozeti, tek/toplu kapatma.
///   `/account/profile` ile aynı gerekçeyle mobile-only.
/// - `/account/blocked` — Engellenen hesaplar (bkz. `features/account/`,
///   ADR-047): liste, boş durum, engel kaldırma. `/account/profile` ile
///   aynı gerekçeyle mobile-only.
/// - `/account/delete` — Hesabı sil (bkz. `features/account/`, ADR-047):
///   silme özeti, iki adımlı onay, taze Auth0 doğrulaması. `/account/profile`
///   ile aynı gerekçeyle mobile-only.
/// - `/notifications` — Bildirimler (bkz. `features/push/`). Hesap
///   gerektirmez, her zaman erişilebilir (`/account`in aksine
///   `AuthFeatureConfig`den bağımsız); `/downloads` ile aynı gerekçeyle
///   mobile-only.
///
/// Kütüphane, Studio rotaları kapsam dışıdır (bkz. PLAN Sınırlar).
///
/// `/account/*` ALT ROTALARI İÇİN EK KAPI: yukarıdaki beş yönetim rotası
/// (`profile`/`security`/`sessions`/`blocked`/`delete`) yalnız
/// `AccountManagementFeatureConfig.enabled` (`ACCOUNT_MANAGEMENT_ENABLED`
/// dart-define, VARSAYILAN `false`) açıkken erişilebilir. Kapalıyken
/// [redirect] bunları FAIL-CLOSED biçimde `/account`a yönlendirir — bu,
/// `AccountHomeScreen`in girişleri hiç render etmemesine EK bir savunma
/// katmanıdır (doğrudan navigasyon/deep-link ile de ulaşılamaz). Gerekçe:
/// hesap yönetimi gerçek `HttpAccountRepository` ile ortak
/// `/api/account/*` sözleşmesine bağlıdır ve geri alınamaz aksiyonlar
/// (hesap silme) içerir; bu yüzden `AUTH_ENABLED` (gerçek Auth0 girişi)
/// ile birlikte otomatik açılmaz — ayrı bir yayın kapısı olarak durur
/// (bkz. `core/config/account_management_feature_config.dart`).
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
      // Hesap YÖNETİMİ kapılı (bkz. `AccountManagementFeatureConfig`,
      // varsayılan `false`): `/account/*` alt rotaları FAIL-CLOSED biçimde
      // güvenli `/account` (Hesabım) ekranına yönlendirilir. Bu, ekranın
      // kendisindeki gizlemeye (bkz. `AccountHomeScreen` — bayrak
      // kapalıyken yönetim girişleri hiç render edilmez) EK bir
      // savunmadır: doğrudan navigasyon veya olası bir deep-link ile bu
      // rotalara ULAŞILAMAZ.
      if (uri.path.startsWith('/account/') &&
          !ref.read(accountManagementFeatureConfigProvider).enabled) {
        return '/account';
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
      GoRoute(
        path: '/downloads',
        builder: (context, state) => const DownloadsScreen(),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: '/account/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/account/security',
        builder: (context, state) => const SecurityScreen(),
      ),
      GoRoute(
        path: '/account/sessions',
        builder: (context, state) => const SessionsScreen(),
      ),
      GoRoute(
        path: '/account/blocked',
        builder: (context, state) => const BlockedAccountsScreen(),
      ),
      GoRoute(
        path: '/account/delete',
        builder: (context, state) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
    ],
  );
});
