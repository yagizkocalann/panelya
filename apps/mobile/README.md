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
  çevirir. Universal Links/App Links (bkz. aşağıki bölüm) tarafından, izin
  verilen bir host için `redirect` içinden çağrılır.

Güvenli düşüş: `lib/app/router/router.dart`'taki `redirect` custom scheme
çevrimini uygular, `errorBuilder` ise (bozuk path, eksik segment, bilinmeyen
scheme gibi) go_router'ın hiçbir rotayla eşleştiremediği her durumda çalışan
`DiscoverScreen`'i gösterir — boş "not found" sayfası veya crash yoktur.

### Universal Links (iOS) / App Links (Android)

`panelya://` custom scheme (yukarıdaki bölüm, ADR-039 auth callback'i dahil)
KORUNUR — Universal/App Links bunun **yerine geçmez**, ayrı bir `https`/`http`
girişidir; auth akışı her zaman custom scheme'de kalır.

**Flutter tarafı (canlı):** `router.dart`'taki `redirect`, `uri.scheme`
`https`/`http` olduğunda `core/config/universal_link_config.dart`'taki
`UniversalLinkConfig` ile host'u denetler. Host allowlist'i derleme zamanı
`UNIVERSAL_LINK_HOSTS` dart-define'ından gelir (virgülle ayrılmış, örn.
`--dart-define=UNIVERSAL_LINK_HOSTS=panelya.app,staging.panelya.app`);
**define verilmezse allowlist BOŞ kalır ve hiçbir `https`/`http` linki kabul
edilmez (fail-closed)**. İzin verilen host için `mapWebPathToMobileRoute`
çağrılır; izin verilmeyen host veya eşlenemeyen path her zaman güvenli
düşüşe (`/`, keşif) gider — bu dal koşulsuz bir sonuç döner, `null` dönüp
go_router'ın path'i host'tan bağımsız biçimde normal rota ağacına karşı
eşlemesine asla izin vermez (bkz. testler:
`test/app/router/router_test.dart` "Universal Links" grubu).

**Android tarafı (altyapı hazır, gerçek domain eksik):**
`AndroidManifest.xml`'de `android:autoVerify="true"` ile ayrı bir `https`
intent-filter var; `android:host` değeri commit edilmez, derleme zamanı
`manifestPlaceholders["appLinkHost"]`'tan gelir
(`android/app/build.gradle.kts`; Gradle özelliği
`-PpanelyaAndroidAppLinkHost=<domain>` veya `PANELYA_ANDROID_APP_LINK_HOST`
ortam değişkeni). İkisi de verilmezse `.invalid` TLD'li (RFC 2606) anlamsız
bir varsayılana düşülür; filtre hiçbir gerçek App Link'i eşlemez.

**iOS tarafı (altyapı hazır, gerçek domain eksik):** `ios/Runner/Runner.entitlements`
(daha önce hiç yoktu, bu vesileyle oluşturuldu)
`com.apple.developer.associated-domains` içinde bilerek çözülemeyen bir
placeholder taşır (`applinks:CONFIGURE_PRODUCTION_DOMAIN.invalid`) ve
`Runner.xcodeproj/project.pbxproj`deki Runner app target'ının Debug/Release/
Profile build config'lerine `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;`
ile bağlandı. **Gerçek domain kararlaştırıldığında** bu placeholder gerçek
domain ile değiştirilmeli VE Xcode'da "Signing & Capabilities" ->
"Associated Domains" capability'si (mevcut Apple Developer takımı +
provisioning profile ile) eklenmeli/onaylanmalıdır — yalnız dosyayı elle
düzenlemek bunun yerine geçmez.

**Web tarafı (canlı, fail-closed):** `/.well-known/apple-app-site-association`
ve `/.well-known/assetlinks.json`, kök repodaki
`app/well-known/apple-app-site-association/route.ts` ve
`app/well-known/assetlinks.json/route.ts` Next.js route handler'larından
sunulur (`app/lib/associated-domains.ts`); gerçek `/.well-known/*` isteği
`next.config.ts`teki bir `rewrites()` kuralıyla bu (nokta içermeyen)
dizinlere yeniden yazılır — derleme aracı (`vinext`) nokta ile başlayan
dizinleri rota taramasından dıştaladığı için gerçek route dosyaları nokta
içermeyen bir yolda durmak zorunda; rewrite bunu istemciye görünmez kılar.
Gerekli değerler (`APPLE_TEAM_ID`, `APPLE_BUNDLE_ID`, `ANDROID_PACKAGE_NAME`,
`ANDROID_SHA256_FINGERPRINTS`) ortamdan gelir; biri eksikse **SAHTE appID/
paket adı/parmak izi asla üretilmez**, uç `503` fail-closed döner.

**Deploy preflight:** kök `scripts/verify-associated-domains-readiness.mjs`
(`npm run associated-domains:preflight`,
`tests/associated-domains-preflight.test.mjs` ile `npm test` içinden
kapsanır) yukarıdaki dört değişkenin varlığını VE biçimsel geçerliliğini
(Apple Team ID 10 alfanumerik, bundle id/paket adı ters-DNS, SHA-256 parmak
izi 32 çift onaltılık basamak) secret yazdırmadan raporlar.

**Kalan dış bağımlılıklar (bu depoda YOK, uydurulmadı):**

- **Production domain kararı** — henüz verilmedi.
- **Apple Developer Team ID** (AASA `appID` için) — `APPLE_TEAM_ID`.
- **Android release imza SHA-256 parmak izi** (Play App Signing yükleme
  anahtarı ve/veya uygulama imzalama anahtarı) — `ANDROID_SHA256_FINGERPRINTS`.

Bu üç değer netleşmeden `UNIVERSAL_LINK_HOSTS` dart-define'ı, web
`APPLE_TEAM_ID`/`APPLE_BUNDLE_ID`/`ANDROID_PACKAGE_NAME`/
`ANDROID_SHA256_FINGERPRINTS` ortam değişkenleri, Android
`PANELYA_ANDROID_APP_LINK_HOST` ve iOS `Runner.entitlements`'teki
`applinks:` girişi gerçek değerlerle doldurulamaz; tüm sistem o zamana kadar
bilinçli olarak fail-closed kalır (hiçbir `https`/`http` deep-link kabul
edilmez, ilgili web uçları 503 döner). Hiçbiri mobil rota şemasını (`/`,
`/series/:slug`, `/series/:slug/read/:episodeSlug`) etkilemez.

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

## Auth (production gateway ve yayın kapısı)

ADR-039 production kimlik sözleşmesini (Auth0, sistem tarayıcılı
Authorization Code + PKCE) tanımlar; ortak schema/OpenAPI/fixture'lar
`packages/contracts` altında, gerçek istemci ve gateway adapter'ları ise
`lib/features/auth/` altındadır. Geliştirme tenant'ıyla callback, token
değişimi, `/api/auth/me`, refresh ve revoke akışları canlı doğrulanmıştır.
Tenant değerleri veya test hesabı bilgileri repoya yazılmaz; web runtime'ı
eksik yapılandırılırsa `/api/auth/config` fail-closed olarak 503 döner.

- `domain/` — `AuthRepository` (soyut: `beginSignIn`/`completeSignIn`/
  `refresh`/`logout` + `currentState`/`stateChanges`) ve `AuthSessionState`
  (`AuthAnonymous`/`AuthAuthenticated`), yalnız
  `lib/core/contracts/generated/auth_*.dart` DTO'larını kullanır.
- `data/pkce.dart` — RFC 7636 `code_verifier`/`code_challenge` (S256)
  üretimi (`package:crypto`, SHA-256 için — bkz. pubspec.yaml gerekçesi).
- `data/auth_browser.dart` — sistem tarayıcısı açma soyutlaması
  (`AuthBrowser`); `SystemAuthBrowser`, `flutter_web_auth_2` ile gerçek
  Authorization Code + PKCE akışını açar.
- `data/fake_auth_repository.dart` — yalnız testlerde açıkça provider
  override'ı olarak kullanılan in-memory sahte.
- `data/http_auth_repository.dart` — gerçek `/api/auth/*` uçlarına
  konuşan ve `presentation/auth_providers.dart` tarafından bağlanan aktif
  adapter.
- `lib/core/storage/token_store.dart` — token saklama sınırı
  (`TokenStore`); gerçek runtime `SecureStorageTokenStore` ile iOS
  Keychain/Android güvenli depolamayı kullanır. `InMemoryTokenStore` yalnız
  testler içindir.
- `lib/core/config/auth_feature_config.dart` — `AUTH_ENABLED` dart-define
  anahtarı (varsayılan `false`). `false` iken `authSessionProvider` hiçbir
  repository örneklemeden her zaman anonim kalır (ADR-010: görünür auth
  butonu/placeholder yok). Bu bir yayın kapısıdır; yalnız hedef ortamın
  Auth0 gateway yapılandırması tamamlandığında `true` verilir.
- `panelya://auth/callback` — Auth0 sistem tarayıcı geri dönüş adresi
  (bkz. `app/router/deep_link.dart` — `authCallbackRedirectUri`,
  `isAuthCallbackUri`). Callback normal bir içerik route'u değildir;
  `SystemAuthBrowser` sonucu doğrudan auth adapter'ına teslim eder.

`AUTH_ENABLED=true` gerçek giriş/çıkış ve temel Hesabım görünümünü açar.
Geri alınamaz hesap yönetimi aksiyonları ayrıca
`ACCOUNT_MANAGEMENT_ENABLED` ile korunur; bu ikinci bayrak ortak
`/api/account/*` runtime'ı ve canlı mutation QA'sı tamamlanmadan yayında
`false` kalır.

## Geliştirme

```sh
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=env/local.json
```

Yeni bir clone'da build almadan önce Firebase istemci yapılandırma
dosyalarını yerine koy — bu dosyaların gerçekleri Git'e commit edilmez,
bkz. [`docs/mobile-firebase-config.md`](../../docs/mobile-firebase-config.md).

### Release build — Android'de `flutter build apk` KULLANMA

Düz `flutter build apk --release` **üç ABI'yi birden** tek bir APK'ya
koyar. Ölçüldü:

| Artefakt | Boyut | Not |
| --- | --- | --- |
| `flutter build apk` (tek APK) | **55.9 MB** | kullanıcı bunu indirir |
| `--split-per-abi`, arm64 | 19.9 MB | cihazın gerçekten kullandığı |
| `--split-per-abi`, armeabi-v7a | 17.4 MB | |
| `--split-per-abi`, x86_64 | 21.3 MB | **yalnız emülatör** |

55.9 MB'ın 51.9 MB'ı native kütüphane; bir cihaz bunlardan yalnız birini
çalıştırır. `x86_64` hiçbir gerçek telefonda kullanılmaz. Tek APK
dağıtmak arm64 kullanıcısına **36 MB fazladan indirtir (%64 israf)**.

Bu yüzden **Play Store'a giden kanonik çıktı `appbundle`'dır**:

```sh
# Play Store (kanonik): Play her cihaza yalniz kendi dilimini indirir
flutter build appbundle --release --dart-define-from-file=env/local.json

# Dogrudan APK dagitimi gerekiyorsa (Play disi, istisnai durum)
flutter build apk --release --split-per-abi --dart-define-from-file=env/local.json
```

#### Release imzalama (fail-closed)

`android/app/build.gradle.kts` release build'i artık **yalnız Git dışı bir
production keystore ile** imzalar; debug anahtarına düşen eski `TODO` kod
yolu kaldırıldı. İmza değerleri iki kaynaktan biriyle sağlanır (bu sırayla
denenir):

1. **`android/key.properties`** (repoya commit edilmez, `.gitignore`'da) —
   yerel/gelistirici makinesinde tek seferlik oluşturulan dosya:

   ```properties
   storeFile=/mutlak/yol/veya/android/koke/gore/relatif/keystore.jks
   storePassword=...
   keyAlias=...
   keyPassword=...
   ```

2. **Ortam değişkenleri** (CI/release makinesi), `key.properties` yoksa
   veya ilgili alan boşsa buraya düşülür:

   - `PANELYA_ANDROID_KEYSTORE_PATH`
   - `PANELYA_ANDROID_KEYSTORE_PASSWORD`
   - `PANELYA_ANDROID_KEY_ALIAS`
   - `PANELYA_ANDROID_KEY_PASSWORD`

`flutter build apk --debug` bu değerlerden hiçbirini gerektirmez ve
etkilenmez. Bir **release** görevi (`flutter build appbundle --release` /
`flutter build apk --release`) tetiklendiğinde yukarıdaki dört değerden
herhangi biri eksikse build, hangi property/env adının eksik olduğunu
söyleyen (değerleri asla yazdırmayan) açık bir `GradleException` ile durur;
hiçbir koşulda sessizce debug anahtarına düşmez. Statik doğrulama
(gradle dosyasının debug fallback içermediği, fail-closed mantığının var
olduğu, `.gitignore`'un keystore desenlerini kapsadığı) kök
`tests/android-release-signing.test.mjs` içinde, `npm test` ile
çalıştırılır — gerçek keystore gerektirmez.

Gerçek production keystore üretimi ve saklanması bu deponun kapsamı
dışındadır; keystore/parola hiçbir zaman Git'e commit edilmez.

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
