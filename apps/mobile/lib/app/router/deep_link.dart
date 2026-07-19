/// Deep-link taslağı (bkz. docs/mobile-handoff.md İlk mobil kapsam #5,
/// apps/mobile/README.md "Deep-link"). İki ayrı sorumluluk burada
/// birleşir:
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
  'contact',
  'copyright',
  'creators',
  'forgot-password',
  'library',
  'login',
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

  return '/';
}
