# Mobil → Web devir bulguları

Bu doküman, mobil tarafın canlı QA turlarında ortaya çıkardığı ve
**çözümü web/altyapı tarafında olan** açık maddeleri toplar. Mobil
tarafta yapılabilecek işler zaten yapılıp `codex/mobile` dalına
alınmıştır; buradakiler mobil koddan kapatılamaz.

Değer taşımayan hiçbir varsayım yazılmadı: her madde canlı bir turda
gözlendi ve nasıl gözlendiği belirtildi.

## 1. Runtime yapılandırması — web tarafında çözüldü, mobil ortama kurulacak

**Durum güncellendi.** Web tarafı Auth0 Management M2M ve account runtime
değerlerini provision etti; **web** oturum envanteri ve şifre yenileme
e-postası canlı doğrulandı. Yani bu artık bir web eksiği değildir.

Kalan iş mobil tarafta ortam kurulumudur: aşağıdaki değerler mobil
geliştirme Mac'inde de **Git dışı yerel runtime dosyasına** (`.dev.vars`,
kök `.gitignore` kapsamında) kurulmalı ki mobil canlı QA turu bu iki
akışı doğrulayabilsin.

| Akış | Gereken değişken adları |
| --- | --- |
| `GET /api/account/sessions` (ve oturum kapatma) | `ACCOUNT_RUNTIME_SECRET` |
| `POST /api/account/password-reset`, e-posta değişikliği | `AUTH0_MANAGEMENT_CLIENT_ID`, `AUTH0_MANAGEMENT_CLIENT_SECRET`, `AUTH0_MANAGEMENT_AUDIENCE` |

Yalnız değişken **adları** listelenmiştir; değerler bu dokümana, herhangi
bir loga veya commit'e yazılmaz.

Mobil tarafta doğrulanmamış olarak kalan: bu iki akışın **mobil**
istemciden çalıştırılması. Son turda mobil ortamda değerler kurulu
olmadığı için sunucu 503 döndü ve istemci bunu doğru ele aldı —
"Aktif oturumlar" ekranı sunucunun `Hesap çalışma anahtarı
yapılandırılmamış.` mesajını olduğu gibi gösterdi, sahte başarı
üretmedi.

**2026-08-02 güncellemesi.** Bu turda repo kökünde `.dev.vars` **hiç**
bulunmadı (bir önceki turun kurulumu, kural gereği tur sonunda silinmişti)
ve çalışır durumda emulator/simulator/dev sunucusu da yoktu. Talimat "yoksa
oluşturma" olduğu için dosya oluşturulmadı; bu yalnız yukarıdaki iki akışı
değil, `AUTH0_GATEWAY_ENABLED` eksik olduğu için **mobil token gateway'inin
tamamını** (dolayısıyla tüm `/api/account/*` ve `/api/auth/mobile/*`
uçlarını) etkiler — bu oturumda hiçbir mobil hesap yönetimi akışı canlı
çalıştırılamadı. Secret değer açmadan hangi adların eksik olduğunu
raporlayan `scripts/verify-mobile-account-live-readiness.mjs`
(`npm run mobile-account:preflight`) eklendi; `tests/mobile-account-preflight.test.mjs`
ile `npm test` içinden kapsanır. Bir sonraki mobil canlı QA turu
`.dev.vars` dosyasını yukarıdaki tam listeyle yeniden kurup bu script
sıfır çıkış koduyla "hazır" diyene kadar devam etmemelidir; adım adım
yönerge `docs/manual-qa-checklist.md` → "Mobil hesap yönetimi canlı QA
adım adım yönergesi" bölümündedir.

Ayrı bir gözlem: mevcut `scripts/verify-auth0-live-readiness.mjs` ve
`scripts/verify-production-deployment-readiness.mjs` kendi `--env-file`
CLI bayrağını kullanıyor; bu isim Node.js 20.6+'ın yerleşik `--env-file`
bayrağıyla çakışır. Hedef dosya yoksa Node, script'in kendi dostane
"okunamadı" hatasını hiç basmadan, kendi opak "not found" mesajıyla (exit
9) çöker. Sonuç yine fail-closed kaldığı için üretim davranışını
bozmaz, ama script'in kendi hata mesajı görünmez. Yeni eklenen
`verify-mobile-account-live-readiness.mjs` bu çakışmayı önlemek için
kasıtlı olarak `--dev-vars` bayrağını kullanır; mevcut iki script'in
düzeltilmesi bu turun kapsamı dışında bırakıldı çünkü onlar hesap
yönetimine özgü değil ve değişiklik diğer dokümü/testleri etkileyebilir.

## 2. `scope=others` — current-device gateway eşlemesi

Web tarafının bildirdiği bilinen sınır: native refresh credential kimliği
access token'dan kesin eşlenemediği için mobilde `scope=others` 503
dönüyor. Mobil istemcide bunu taklit eden bir "başarılı göster" yolu
**yoktur**; hata olduğu gibi yüzeye çıkar. Bu teslim beklemede.

## 3. Auth0 tenant'ında Türkçe kapalı

`ui_locales=tr` üç yerden de gönderiliyor
(`app/lib/auth0-web.ts`, `app/lib/account-reauthentication.ts`,
`apps/mobile/lib/features/auth/data/http_auth_repository.dart`), ancak
Universal Login sayfası **İngilizce** geliyor ("Welcome / Log in to
panelya-dev-eu to continue to Panelya").

Kod tarafında eksik yok; tenant'ın Universal Login dil ayarında Türkçe
etkinleştirilmeli. Gözlem: iOS ve Android canlı giriş turları.

## 4. iOS'ta fazladan onay adımı (bilgilendirme)

iOS'ta sistem tarayıcısı `ASWebAuthenticationSession` ile açılıyor ve
işletim sistemi Android'de karşılığı olmayan bir onay soruyor:
*"panelya_mobile giriş yapmak için şunu kullanmak istiyor: auth0.com"*.

Bu bir hata değil, platform davranışı; kaldırılamaz (gömülü WebView
ADR-039 ile yasak). Ürün tarafı akış sayımı yaparken bilsin diye
kaydedildi. Aynı onay hem giriş hem taze kimlik doğrulama akışında çıkar.

## 5. iOS push yalnız gerçek cihazda doğrulanabilir

APNs simulator'da çalışmaz, dolayısıyla iOS push teslimi ve deep-link
açılışı emülatörde test edilemez. Android tarafında uçtan uca doğrulandı
(topic aboneliği, gerçek FCM teslimi, deep-link açılışı).

Mobil tarafta ilgili kod sertleştirildi: APNs token'ı hazır değilken
abonelik artık sessizce kaybolmuyor (bkz. `codex/mobile`,
`apns_token_wait.dart`).

**2026-08-02 güncellemesi — cihaz erişilebilirlik denemesi + yeni somut
bulgu.** `xcrun xctrace list devices` iki eşleşmiş fiziksel iPhone gösterdi
("Yağız iPhone'u", "kca") ama ikisi de "Devices Offline" altındaydı;
`flutter devices` her ikisi için de "Ensure the device is unlocked and
attached with a cable or associated with the same local area network as
this Mac. The device must be opted into Developer Mode to connect
wirelessly. (code -27)" hatası verdi. Yani bu oturumda da HİÇBİR fiziksel
cihaz erişilebilir değildi; APNs teslimi/deep-link açılışı yine canlı
doğrulanamadı. Sahte sonuç üretilmedi.

Bunun yerine `scripts/verify-ios-push-readiness.mjs`
(`npm run ios-push:preflight`, `tests/ios-push-preflight.test.mjs` ile
`npm test` içinden kapsanır) eklendi — Info.plist, `project.pbxproj` ve
`GoogleService-Info.plist`/`Runner.entitlements` VARLIĞINI secret
göstermeden statik olarak denetler. Bu turda çalıştırıldığında **gerçek
projede `ios/Runner/Runner.entitlements` dosyası hiç yok ve
`project.pbxproj`de `CODE_SIGN_ENTITLEMENTS` build ayarı hiç kayıtlı
değil** bulundu — yani Xcode'da Push Notifications capability henüz hiç
eklenmemiş. Bu, önceki turlarda "yalnız gerçek cihazda doğrulanabilir"
olarak genel geçtirilmiş ama daha önce hiç bu şekilde isimlendirilmemiş
somut bir dış bağımlılıktı: gerçek cihaz erişilebilir olsa BİLE bu
capability Xcode'da eklenip geçerli bir provisioning profile ile
eşleştirilmeden APNs kaydı muhtemelen başarısız olur.

Ayrıca `FirebasePushNotificationRepository`'nin önceden HİÇ otomatik testi
olmayan üç davranışı (token geç gelirse abonelik yine tamamlanır mı, token
hiç gelmezse durum dürüstçe raporlanır mı, soğuk başlangıç/arka planda
bekleyen bildirim kaybolur mu) Firebase eklenti sınırının dışına çıkarılıp
(`withApnsRetry`, `notificationTapStream`, `resolveDeepLink`,
`isAuthorizedStatus` — `apps/mobile/lib/features/push/data/`) saf Dart
fonksiyonları olarak test edildi (bkz.
`apps/mobile/test/features/push/data/apns_retry_test.dart`,
`notification_tap_stream_test.dart`, `push_deep_link_test.dart`,
`push_authorization_test.dart`). Adım adım canlı QA yönergesi
`docs/manual-qa-checklist.md` → "iOS push canlı QA adım adım yönergesi"
bölümündedir; eksiksiz dış bağımlılık listesi (yalnız adlar) o script'in
`IOS_PUSH_EXTERNAL_DEPENDENCIES` sabitinde ve aşağıda tekrarlanır:

- Apple Developer Program üyeliği (ücretli, aktif).
- Xcode "Signing & Capabilities" → "Push Notifications" capability
  (`Runner.entitlements`'ı üretir).
- Push Notifications destekleyen geçerli bir provisioning profile
  (Development veya Distribution, projenin `DEVELOPMENT_TEAM`'iyle eşleşen).
- APNs Auth Key (.p8) + Key ID + Team ID → Firebase Console → Cloud
  Messaging → Apple app configuration'a yüklü olmalı.
- Fiziksel bir iPhone (Simulator APNs token ALAMAZ).
- Sunucu tarafı gönderim değişkenleri `FCM_PROJECT_ID` / `FCM_CLIENT_EMAIL`
  / `FCM_PRIVATE_KEY` — bunlar zaten
  `scripts/verify-production-deployment-readiness.mjs` tarafından
  denetleniyor, burada tekrar edilmedi.

## 6. Hesap silme akışı — disposable hesap gerekiyor

`POST /api/account/deletion` **hiçbir platformda çalıştırılmadı**. Elde
yalnız geliştiricinin gerçek kişisel hesabı vardı; silme geri alınamaz
olduğu için kasıtlı olarak denenmedi.

İstemci tarafı hazır ve testli: iki aşamalı onay, amaca bağlı taze kimlik
doğrulama, `Idempotency-Key`, asenkron `pending` durumunun dürüst
gösterimi. Doğrulama için tek gereken bir **disposable Auth0 test
hesabı**.

## 7. Android release dağıtımı — tek APK kullanılmamalı

Mobil tarafın kendi kararı olmakla birlikte yayın sürecini ilgilendirdiği
için burada da not ediliyor: düz `flutter build apk --release` üç ABI'yi
tek APK'ya koyuyor (55.9 MB); cihaz bunlardan yalnız birini kullanıyor
(arm64 için 19.9 MB). Play yayını `appbundle` ile yapılmalı.

Ayrıntı ve ölçümler: `apps/mobile/README.md` → "Release build".

Güncelleme: `android/app/build.gradle.kts` artık release'i debug
anahtarıyla imzalamıyor. Release imzası yalnız `android/key.properties`
(Git dışı) veya `PANELYA_ANDROID_*` ortam değişkenlerinden gelir; bu iki
kaynaktan biri eksikse `flutter build appbundle --release` / `flutter
build apk --release` hangi değerin eksik olduğunu söyleyen (değer
yazdırmayan) açık bir hata ile durur — sessizce debug anahtarına
düşmez. Ayrıntı: `apps/mobile/README.md` → "Release imzalama
(fail-closed)"; statik doğrulama `tests/android-release-signing.test.mjs`
içinde.

## 8. Kütüphane/favori — ortak sözleşme web tarafından teslim edildi

Web'de çalışan bir özellik mobilde hiç yok:

| Yüzey | Web | Mobil |
| --- | --- | --- |
| Sayfa/ekran | `/library` ("Kütüphanem", `SiteFooter`'da) | **yok** |
| API | `GET /api/library`, `POST/DELETE /api/library/{slug}` | mobil entegrasyonu bekliyor |
| Ortak sözleşme | Schema/OpenAPI 1.5.0 + `library-*.v1.json` | codegen ve adapter bekliyor |

ADR-048 ile `LibraryStatus`, `LibraryItem`, liste/upsert/removal ve hata
tanımları kanonik sözleşmeye eklendi. Liste yalnız public seri kart metadata'sı,
`episodeCount`, durum, favori ve server sıralama zamanını taşır; panel veya
internal medya metadata'sı taşımaz.

Bunun somut bir yan etkisi vardı: mobil giriş ekranı *"kütüphaneni ve
favorilerini senkronize et"* diyerek kullanıcıyı uygulamanın hiç
sunmadığı bir özellik için giriş yapmaya davet ediyordu. Metin, girişin
bu sürümde gerçekten sağladığıyla değiştirildi (ADR-010, bkz.
`account_screen.dart`). Kütüphane geldiğinde geri güncellenecek.

**Mobilde sıradaki:** Değişiklik `main`e girdikten sonra deterministik Dart
codegen, `library-*.v1.json` parser testleri ve cookie taklit etmeyen Bearer
`HttpLibraryRepository`. `GET` için `read:library`, `POST/DELETE` için
`write:library` kullanılır. JSON `POST` toggle değil hedef `status` + `favorite`
tam durumunu gönderir; `DELETE removed:false` başarılı idempotent sonuçtur.
