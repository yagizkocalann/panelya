# panelya_mobile

Panelya'nın Flutter mobil istemcisi (Faz 1 iskeleti). Web uygulamasının
`/api/*` sınırını kullanan ayrı bir istemcidir (ADR-019); web UI kodu
taşınmaz. Ayrıntılar için repo kökündeki `production-bible.md` (özellikle
ADR-019) ve `docs/mobile-handoff.md`'ye bakın.

## Kapsam (Faz 1)

- Keşif/katalog listesi (`GET /api/catalog`)
- Seri detay ve bölüm listesi (`GET /api/series/:slug`)
- Dikey okuyucu (`GET /api/series/:slug/episodes/:episodeSlug`)
- Yükleniyor/boş/hata (tekrar dene ile)/başarı durumları
- Deep-link hazır rotalar: `/`, `/series/:slug`, `/series/:slug/read/:episodeSlug`

Auth, favori/kütüphane, push, çevrimdışı, ödeme ve Studio ekranları bu
fazın kapsamı dışındadır.

## Deep-link

`panelya://` custom scheme'i canlıdır (bkz. docs/mobile-handoff.md İlk
mobil kapsam #5):

- `panelya://` -> keşif (`/`)
- `panelya://series/<slug>` -> seri detay (`/series/:slug`)
- `panelya://series/<slug>/read/<episodeSlug>` -> okuyucu
  (`/series/:slug/read/:episodeSlug`)

Platform yapılandırması:

- iOS: `ios/Runner/Info.plist` içinde `CFBundleURLTypes` (`panelya` scheme'i)
  ve `FlutterDeepLinkingEnabled` (`true`, Flutter 3.44'te zaten varsayılan —
  niyeti belgelemek için açıkça eklendi).
- Android: `android/app/src/main/AndroidManifest.xml` içinde
  `.MainActivity`'ye eklenen `panelya` scheme'li bir `intent-filter`
  (`android:autoVerify` YOK — bu yalnız http(s) Android App Links'te domain
  sahipliğini doğrulamak için kullanılır, custom scheme'de karşılığı yoktur)
  ve aynı gerekçeyle açıkça eklenen `flutter_deeplinking_enabled` meta-data.

Rota çözümleme mantığı `lib/app/router/deep_link.dart` içinde, testleri
`test/app/router/deep_link_test.dart` ve `test/app/router/router_test.dart`
içindedir:

- `resolveCustomSchemeRoute` — bugün canlı olan `panelya://` linklerini
  go_router path'ine çevirir; hiçbir zaman null dönmez (tanınmayan/bozuk her
  girdi keşfe düşer).
- `mapWebPathToMobileRoute` — web URL yapısını (`/<slug>`,
  `/<slug>/<episodeSlug>`, bkz. `app/[slug]/[episode]`) mobil rota yapısına
  çevirir. Bugün router'da kullanılmıyor; Universal Links/App Links
  eklendiğinde kullanılacak (bkz. aşağıdaki "Gelecek adım").

Güvenli düşüş: `lib/app/router/router.dart`'taki `redirect` custom scheme
çevrimini uygular, `errorBuilder` ise (bozuk path, eksik segment, bilinmeyen
scheme gibi) go_router'ın hiçbir rotayla eşleştiremediği her durumda çalışan
`DiscoverScreen`'i gösterir — boş "not found" sayfası veya crash yoktur.

### Gelecek adım: Universal Links (iOS) / App Links (Android)

Production domain kararı henüz verilmedi; bu yüzden http(s) tabanlı
Universal Links/App Links bu fazda uygulanmadı. Domain kararı verildiğinde
şunlar gerekir:

- **iOS**: Apple App Site Association (AASA) dosyası — web deployment'ında
  `/.well-known/apple-app-site-association` altında sunulmalı (imzasız JSON,
  `Content-Type: application/json`); `appID` (Team ID + Bundle ID) ve izin
  verilen path'ler (`/*` veya belirli desenler) belirtir. Xcode tarafında
  `com.apple.developer.associated-domains` entitlement'ına
  `applinks:<domain>` eklenir (yeni bir `Runner.entitlements` dosyası veya
  mevcut birine ekleme gerekir — bugün proje bir entitlements dosyası
  içermiyor).
- **Android**: Digital Asset Links dosyası — web deployment'ında
  `/.well-known/assetlinks.json` altında sunulmalı; uygulamanın SHA-256
  imza parmak izi ve `package_name`'i içerir. `AndroidManifest.xml`'e
  `android:autoVerify="true"` ile ayrı bir `https` intent-filter eklenir
  (bkz. bu dosyadaki custom scheme intent-filter'ının hemen yanı — aynı
  `.MainActivity` içinde, `android:host="<domain>"` ile).
- **Flutter tarafı**: `lib/app/router/router.dart`'taki `redirect`
  içine, gelen `uri.scheme` `https`/`http` olduğunda `path` (+ gerekirse
  `query`) üzerinde `mapWebPathToMobileRoute` çağıran bir dal eklenir; bu
  fonksiyon zaten yazılı ve test edilmiş durumda (yalnız henüz
  çağrılmıyor).
- Bu üç değişikliğin hiçbiri mobil rota şemasını (`/`, `/series/:slug`,
  `/series/:slug/read/:episodeSlug`) etkilemez.

## Ortam yapılandırması (API origin)

API origin'i kaynak koda gömülmez; derleme zamanında
`--dart-define-from-file` ile enjekte edilir. `env/local.json`:

```json
{
  "API_ORIGIN": "http://localhost:3000"
}
```

Çalıştırma:

```sh
flutter run --dart-define-from-file=env/local.json
```

Bir define verilmezse `API_ORIGIN` varsayılan olarak
`http://localhost:3000`'e düşer (bkz. `lib/core/config/app_config.dart`).

### Fiziksel cihazda test etme

Simulator/emulator aynı Mac'te çalışan web API'sine `localhost` üzerinden
erişebilir. **Fiziksel bir cihazda `localhost` telefonun kendisini işaret
eder, Mac'i değil.** Fiziksel cihaz testinde `env/local.json` içindeki
`API_ORIGIN` değerini Mac'in yerel ağ adresine ayarlayın, örn.:

```json
{
  "API_ORIGIN": "http://192.168.1.23:3000"
}
```

Mac'in yerel ağ adresini `ipconfig getifaddr en0` (Wi-Fi) ile bulabilirsiniz.
Telefon ve Mac aynı yerel ağda olmalı ve web geliştirme sunucusu
(`npm run dev`, repo kökünde) çalışıyor olmalıdır.

#### Cleartext (http://) izni: Android ve iOS farkı

Flutter 1.23+ (bkz. Flutter "Network policy" breaking change,
docs.flutter.dev/release/breaking-changes/network-policy-ios-android),
Android 9 (API 28)+ ve iOS'un cleartext-engelleme varsayımını `dart:io`
katmanına da taşıdı: yukarıdaki gibi düz `http://192.168.x.x:3000`
kullanmak platform tarafından reddedilir ("Insecure HTTP is not allowed
by platform"), açık bir izin gerekir. İki platform de aynı çözümü
desteklemediği için davranış farklıdır:

- **Android**: `android/app/src/debug/res/xml/network_security_config.xml`
  ve aynı dizindeki `AndroidManifest.xml` (`android:networkSecurityConfig`)
  yalnız DEBUG build variant'ında cleartext'e izin verir (bkz. bu iki
  dosyadaki ayrıntılı yorumlar). Bu yüzden fiziksel Android cihazda yukarıdaki
  `http://192.168.x.x:3000` origin'i `flutter run` ile doğrudan çalışır;
  release derlemesine (`flutter build apk --release` / `appbundle`) hiçbir
  cleartext izni sızmaz (doğrulandı: release APK'nin gömülü manifestinde
  `networkSecurityConfig` özniteliği yok, `aapt2 dump xmltree` ile
  kontrol edilebilir).
- **iOS**: Xcode/Flutter tek bir `Info.plist` kullanır; Android'deki gibi
  yalnız debug'a etki eden ayrı bir kaynak seti mekanizması yoktur. Bu
  yüzden `ios/Runner/Info.plist`'e KASITLI OLARAK hiçbir
  `NSAppTransportSecurity` istisnası eklenmedi (bkz. dosyadaki ayrıntılı
  yorum): `NSAllowsArbitraryLoads` her yerde her HTTP'yi açar (release'e de
  sızar, güvenlik açısından kabul edilemez); sabit bir IP için
  `NSExceptionDomains` ise geliştiriciden geliştiriciye/ağdan ağa değişen
  bir değeri repoya commit etmeyi gerektirir (yanlış/işe yaramaz hale
  gelir) ve her IP değişiminde Xcode yeniden derlemesi ister — fiziksel
  cihaz iterasyonunu Android'dekinden çok daha yavaşlatır. Bunun yerine
  **fiziksel iOS cihazında test ederken `env/local.json`'daki
  `API_ORIGIN`'i düz HTTP LAN IP'si yerine web geliştirme sunucusuna giden
  bir HTTPS geliştirme tüneline (örn. `ngrok http 3000`, Cloudflare
  Tunnel) ayarlayın**, örn.:

  ```json
  {
    "API_ORIGIN": "https://<tunnel-alt-adi>.ngrok-free.app"
  }
  ```

  Bu, zaten HTTPS olduğu için hiçbir Info.plist değişikliği gerektirmeden
  ATS/Flutter ağ politikasını doğal olarak karşılar ve Simulator'daki
  `localhost` (her zaman istisna, loopback) ile fiziksel cihazdaki
  davranışı tutarlı kılar. Düz HTTP + LAN IP üzerinde ısrar edilirse
  `Info.plist`'e geçici, **commit edilmeyen** bir `NSExceptionDomains`
  girişi eklenip test sonrası geri alınabilir; bu depoya asla sabit bir
  IP veya `NSAllowsArbitraryLoads` commit edilmez.

## Auth (adapter sınırı — henüz canlı bir login akışı DEĞİL)

ADR-039 production kimlik sözleşmesini (Auth0, sistem tarayıcılı
Authorization Code + PKCE) tanımlar ve ortak schema/OpenAPI/fixture'lar
`packages/contracts` altında hazırdır; ama gerçek Auth0 tenant, token
gateway ve JWKS doğrulaması henüz sağlanmadı (bkz.
docs/production-auth-session.md "Kalan deployment kapıları"). Bu yüzden
`lib/features/auth/` bugün yalnız SINIR mimarisini kurar:

- `domain/` — `AuthRepository` (soyut: `beginSignIn`/`completeSignIn`/
  `refresh`/`logout` + `currentState`/`stateChanges`) ve `AuthSessionState`
  (`AuthAnonymous`/`AuthAuthenticated`), yalnız
  `lib/core/contracts/generated/auth_*.dart` DTO'larını kullanır.
- `data/pkce.dart` — RFC 7636 `code_verifier`/`code_challenge` (S256)
  üretimi (`package:crypto`, SHA-256 için — bkz. pubspec.yaml gerekçesi).
- `data/auth_browser.dart` — sistem tarayıcısı açma soyutlaması
  (`AuthBrowser`); tek implementasyon `SystemAuthBrowser` bilerek bir
  STUB'tır (`url_launcher` henüz eklenmedi).
- `data/fake_auth_repository.dart` — in-memory sahte; Riverpod
  provider'ları (`presentation/auth_providers.dart`) BUGÜN BUNU bağlar.
- `data/http_auth_repository.dart` — gerçek `/api/auth/*` uçlarına
  konuşan iskelet; hiçbir provider'dan bağlanmaz, canlıda çağrılmaz.
- `lib/core/storage/token_store.dart` — token saklama sınırı
  (`TokenStore`); tek implementasyon `InMemoryTokenStore`
  (`flutter_secure_storage` henüz eklenmedi, arayüz onu bekleyecek şekilde
  async tasarlandı).
- `lib/core/config/auth_feature_config.dart` — `AUTH_ENABLED` dart-define
  anahtarı (varsayılan `false`). `false` iken `authSessionProvider` hiçbir
  repository örneklemeden her zaman anonim kalır (ADR-010: görünür auth
  butonu/placeholder yok). Gerçek tenant/gateway/JWKS entegrasyonu
  tamamlanana kadar bu bayrak `true` yapılmaz.
- `panelya://auth/callback` — Auth0 sistem tarayıcı geri dönüş adresi
  (bkz. `app/router/deep_link.dart` — `authCallbackRedirectUri`,
  `isAuthCallbackUri`); bir ekranı yoktur, `resolveCustomSchemeRoute`
  onu tanımadığı için (bilerek) her zaman keşfe düşer.

Bu pakette bir login/hesap ekranı YOKTUR (kapsam dışı, bkz.
docs/mobile-handoff.md "Şimdilik sonraya bırakılanlar"). Gerçek tenant
sağlandığında geçiş tek noktadan yapılır: `authRepositoryProvider` ve
`authBrowserProvider` içindeki örneklemeler `HttpAuthRepository`/gerçek
bir `AuthBrowser` ile değiştirilir, `AUTH_ENABLED=true` dart-define'ı
verilir.

## Geliştirme

```sh
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=env/local.json
```

## Mimari notlar

- **Tema**: `lib/app/theme/` — tüm renk/spacing/tipografi token'ları
  `docs/mobile-handoff.md`'deki tabloyla birebir eşleşir. Koyu tema tek
  temadır. Ekranlar token dışında değer hardcode etmez.
- **Sözleşmeler**: `lib/core/contracts/` — `packages/contracts` `main`'e
  gelene kadar geçici tek adapter katmanı (her dosyanın başında bu not
  bulunur). Web tarafının `app/api/catalog`, `app/api/series/[slug]` ve
  `app/api/series/[slug]/episodes/[episode]` route handler'larının
  döndürdüğü gerçek JSON şeklini birebir aynalar.
- **API client**: `lib/core/api/` — tek merkezi HTTP client; network/4xx/5xx
  /parse hata ayrımı ve `schemaVersion` uyumsuzluğunda açık hata fırlatır.
  Ekranlar bu client'ı doğrudan değil, her feature'ın repository interface'i
  (Riverpod provider'ı) üzerinden kullanır.
- **Router**: `lib/app/router/` — go_router, deep-link hazır üç rota;
  `panelya://` custom scheme çözümü ve bilinmeyen/bozuk link güvenli düşüşü
  dahil (ayrıntı için yukarıdaki "Deep-link" bölümüne bakın).
- **Feature-first yapı**: `lib/features/<feature>/{domain,data,presentation}`
  (Novel-Project'ten devralınan kalıp; Firebase/video player/AdMob/RevenueCat
  kodu kopyalanmadı).
