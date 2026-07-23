/// Deep-link taslağı (bkz. docs/mobile-handoff.md İlk mobil kapsam #5,
/// apps/mobile/README.md "Deep-link"). Üç ayrı sorumluluk burada birleşir:
///
/// 1. [resolveCustomSchemeRoute] — bugün canlı olan `panelya://` custom
///    scheme linklerini go_router rota path'ine çevirir.
/// 2. [mapWebPathToMobileRoute] — web tarafının URL yapısını (`/<slug>`,
///    `/<slug>/<episodeSlug>`, bkz. `app/[slug]/[episode]`) mobil rota
///    yapısına (`/series/:slug`, `/series/:slug/read/:episodeSlug`)
///    çevirir. Bugün hiçbir yerden çağrılmıyor; production domain kararı
///    verilip Universal Links (iOS) / App Links (Android) eklendiğinde
///    router'ın `redirect`'i içinde kullanılacak (bkz. README "Gelecek
///    adım"). Mobil rota şeması o zaman değişmeyecek — yalnız bu
///    fonksiyon yeni bir intent-filter/associated domain'den gelen
///    path'leri besleyecek.
/// 3. [isAuthCallbackUri] / [authCallbackRedirectUri] — production auth
///    sözleşmesinin (ADR-039) sistem tarayıcı Authorization Code + PKCE
///    geri dönüş adresini aynı `panelya://` şeması altında tanımlar (bkz.
///    `features/auth/`). Bu üçüncü sorumluluk go_router'ın gezinme
///    rotalarından bağımsızdır — auth callback'inin bir ekranı yoktur.
library;

/// Web tarafının ürün rotası olmayan kök segmentleri (bkz. `app/`
/// dizinindeki kardeş klasörler: about, login, studio, vb.). Bunlar bir
/// seri slug'ıyla asla çakışmaz çünkü web tarafında slug route'u
/// (`app/[slug]`) bu isimlerle bir seri oluşturulmasına izin vermez; yine
/// de mobil tarafta yanlışlıkla "seri" sanılıp okuyucuya düşürülmesinler
/// diye burada açıkça eleniyor.
const _webOnlyTopLevelSegments = {
  'about',
  'account',
  'api',
  // Web tarafındaki gerçek route'lar (bkz. `app/catalog`, `app/new-series`,
  // `app/new-episodes`, `app/updates` — editorial keşif ayrımı, bkz.
  // docs/mobile-handoff.md "Editorial keşif akışı"); mobilde de aynı
  // isimlerle karşılıkları vardır (`/catalog`, `/new-series`,
  // `/new-episodes`) ama bu fonksiyon yalnız web'in `/<slug>` seri
  // path'ini mobil rotaya çevirir — bu dört isim asla bir seri slug'ı
  // olamayacağı için burada da eleniyor.
  'catalog',
  'contact',
  'copyright',
  'creators',
  'forgot-password',
  'library',
  'login',
  'new-episodes',
  'new-series',
  'privacy',
  'production-journal',
  'publishing-principles',
  'register',
  'reset-password',
  // 'series' web tarafında kullanılmıyor ama mobil rota önekiyle
  // karışmaması için güvenlik payı olarak burada tutuluyor.
  'series',
  'studio',
  'terms',
  'updates',
  'verify-email',
};

/// Web URL path'ini (`/<slug>` veya `/<slug>/<episodeSlug>`) mobil rota
/// path'ine (`/series/<slug>` veya `/series/<slug>/read/<episodeSlug>`)
/// çevirir.
///
/// - `/` veya boş path -> `/` (keşif).
/// - `/gece-vardiyasi` -> `/series/gece-vardiyasi`.
/// - `/gece-vardiyasi/bolum-1` -> `/series/gece-vardiyasi/read/bolum-1`.
/// - Web-only kök segment (`/about` gibi), 3+ segment veya boş slug/
///   episodeSlug segmenti içeren bozuk path -> `null`.
///
/// `null` dönüşü çağıran tarafın güvenli düşüşü (bkz. [resolveCustomSchemeRoute]
/// ve router'daki `redirect`/`errorBuilder`) uygulaması gerektiği anlamına
/// gelir; bu fonksiyon kendisi asla varsayılan bir rotaya düşmez, saf bir
/// eşleme kalır.
String? mapWebPathToMobileRoute(String webPath) {
  final segments = Uri.parse(webPath).pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);

  if (segments.isEmpty) {
    return '/';
  }

  final slug = segments[0];
  if (_webOnlyTopLevelSegments.contains(slug)) {
    return null;
  }

  if (segments.length == 1) {
    return '/series/$slug';
  }

  if (segments.length == 2) {
    final episodeSlug = segments[1];
    return '/series/$slug/read/$episodeSlug';
  }

  // 3+ segment: web tarafında böyle bir rota yok.
  return null;
}

/// `panelya://` custom scheme deep link'ini go_router rota path'ine
/// çevirir. Her zaman geçerli bir mobil rota path'i döner (`/`,
/// `/series/:slug` veya `/series/:slug/read/:episodeSlug`); tanınmayan,
/// bozuk veya beklenmeyen scheme'e sahip her girdi için `/` (keşif) döner
/// — hiçbir zaman `null` veya exception fırlatmaz (güvenli düşüş, bkz.
/// PLAN Görev 3).
///
/// Custom scheme URI'lerde `://` sonrası ilk parça URI ayrıştırıcısı
/// tarafından authority/host olarak kabul edilir (ör. `panelya://series/x`
/// için `host == 'series'`, `path == '/x'`); yalnız `uri.path` kullanmak bu
/// yüzden "series" parçasını kaybeder. Bu fonksiyon `uri.host` (varsa) ve
/// `uri.path` segmentlerini birleştirerek hem `panelya://series/x` hem de
/// `panelya:///series/x` (üçlü slash, boş host) biçimlerini aynı şekilde
/// çözer.
String resolveCustomSchemeRoute(Uri uri) {
  if (uri.scheme != 'panelya') {
    return '/';
  }

  final segments = [
    if (uri.host.isNotEmpty) uri.host,
    ...uri.path.split('/').where((segment) => segment.isNotEmpty),
  ];

  if (segments.isEmpty) {
    return '/';
  }

  if (segments.length == 2 && segments[0] == 'series') {
    final slug = segments[1];
    return '/series/$slug';
  }

  if (segments.length == 4 &&
      segments[0] == 'series' &&
      segments[2] == 'read') {
    final slug = segments[1];
    final episodeSlug = segments[3];
    return '/series/$slug/read/$episodeSlug';
  }

  // `panelya://auth/callback` (bkz. [isAuthCallbackUri] ve
  // [authCallbackRedirectUri]) bu üç mobil rotadan biri DEĞİLDİR — hiçbir
  // ekranı yok, bu yüzden burada da güvenli düşüş rotasına (`/`) çevrilir.
  // Gerçek Auth0 sistem tarayıcı oturumu (bkz.
  // `features/auth/data/auth_browser.dart`) bu URI'yi zaten go_router'a
  // ulaşmadan doğrudan yakalar (`ASWebAuthenticationSession`/Custom Tabs
  // callback yakalama); bu fonksiyon yalnız işletim sisteminin linki genel
  // deep-link kanalına da dağıttığı durumda çökme/boş ekran olmamasını
  // garanti eder.
  return '/';
}

/// Auth0 sistem tarayıcı Authorization Code + PKCE akışının geri dönüş
/// adresi (bkz. ADR-039, docs/production-auth-session.md). Native public
/// client olarak Auth0 tenant'ına KAYITLI OLACAK sabit bir değerdir (tenant
/// provision edildiğinde bu URI, Auth0 Application ayarlarındaki "Allowed
/// Callback URLs" listesine eklenir); ortama/cihaza göre değişmediği için
/// `env/` dart-define katmanından değil buradan, tek bir sabit olarak
/// okunur (bkz. `AppConfig.apiOrigin` ile karşılaştır — o gerçekten
/// ortama göre değişir, bu değişmez).
const authCallbackRedirectUri = 'panelya://auth/callback';

/// [uri] `panelya://auth/callback` biçiminde bir Auth0 sistem tarayıcı
/// callback'i mi (query'de `code`/`state` ya da `error` taşır).
///
/// Bu, [resolveCustomSchemeRoute]'un tanıdığı üç navigasyon rotasından
/// (`/`, `/series/:slug`, `/series/:slug/read/:episodeSlug`) FARKLI bir
/// sınıftır: bir ekranı yoktur, bu yüzden [resolveCustomSchemeRoute] onu
/// (bugün olduğu gibi) her zaman güvenli düşüş rotasına (`/`) çevirir. Bu
/// fonksiyon `panelya://` şemasının ikinci bir tüketicisi için —
/// `AuthRepository.completeSignIn` içinde, sistem tarayıcısından dönen
/// URI'nin gerçekten beklenen callback şeklinde olduğunu ikinci bir
/// savunma katmanı olarak doğrulamak için — ayrı bir pure fonksiyon olarak
/// dışa açılır.
bool isAuthCallbackUri(Uri uri) {
  if (uri.scheme != 'panelya') return false;

  final segments = [
    if (uri.host.isNotEmpty) uri.host,
    ...uri.path.split('/').where((segment) => segment.isNotEmpty),
  ];

  return segments.length == 2 &&
      segments[0] == 'auth' &&
      segments[1] == 'callback';
}
