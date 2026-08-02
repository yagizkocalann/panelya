# Production hesap yasam dongusu (ADR-047)

## Karar

`Hesabim`, web ve Flutter icin ayni Panelya hesap merkezidir. Platformlar ayni
ekran bilesenlerini kullanmak zorunda degildir; ancak ayni yetenekleri, ayni
sunucu kurallarini ve `packages/contracts` altindaki ayni JSON sozlesmesini
kullanir.

Standart hesap kapsami iki platformda da sunlari icerir:

1. hesap bilgisi ve profil,
2. salt okunur e-posta ve dogrulama durumu,
3. sifre/kimlik bilgisi yonetimi,
4. aktif oturumlar ve tekil/toplu oturum iptali,
5. engellenen hesaplar ve engeli kaldirma,
6. hesabi silme.

Studio rolleri ve yonetici islemleri bu kapsama girmez.

## Yerel ve production siniri

Mevcut `/api/account/email`, `/api/account/password`,
`/api/account/delete` ve D1 `sessions` tablosuna dogrudan bagli form akislari
yalniz localhost PBKDF2 QA adaptoru olarak kalir. Bunlar mobil sozlesme veya
production Auth0 davranisi sayilmaz.

Production hesap API'si:

- web host-only Panelya session cookie'sini,
- Flutter ise dogrulanmis Panelya API audience Bearer access tokenini

ayni `AccountActor` sunucu sinirina donusturur. Mobil icin ikinci bir
`/api/account/mobile/*` yuzu acilmaz. `/api/auth/mobile/*` ayrimi yalniz native
OAuth code/refresh/revoke tasimasina aittir.

## Sifre degistirme

Panelya production'da mevcut veya yeni sifreyi kendi formuna almaz.

- Auth0 database kullanicisi icin ortak hesap ucu, oturumdaki kullanicinin
  provider e-postasina Auth0
  `POST /dbconnections/change_password` uzerinden sifre yenileme e-postasi
  ister ve hesap varligini sizdirmayan `202 Accepted` doner.
- Google veya baska bir sosyal kimlikte Panelya tarafinda sifre yoktur. Hesap
  yetenek cevabi bunu `provider_managed` olarak bildirir; istemci kullaniciyi
  ilgili kimlik saglayicisinin guvenlik ayarlarina yonlendirir.
- Basarili sifre degisikliginden sonra D1 web oturumlari ve Auth0 refresh
  oturumlari kapatilir. Daha once verilmis API access tokenlari en gec 15
  dakika icinde biter; yuksek riskli mutation'lar ayrica oturum iptal
  zamanini denetler. Auth0 password-change Action/webhook'u Panelya
  session-revocation isini idempotent tetiklemeden bu garanti tamamlanmis
  sayilmaz.

Yerel `eski sifre + yeni sifre` formu production UI'da gosterilmez.

## E-posta degistirme

E-posta mevcut urun kapsaminda salt okunur hesap bilgisidir. Ortak
`AccountCapabilities.emailChange` tum providerlarda `unavailable` doner; web ve
Flutter form, buton veya provider'a yonlendiren bir e-posta degistirme aksiyonu
gostermez. Sunucu `/api/account/email-change` ve `email_change` reauthentication
baslangicini capability kapaliyken `unsupported_action` ile fail-closed reddeder.

Ortak DTO, reauthentication purpose ve endpoint sekli gelecekte ayri bir urun
karariyla yeniden acilabilmesi icin korunur. Yeniden acilacaksa taze Auth0
dogrulamasi, server-side Management API, yeni adres dogrulamasi ve D1 claim
uzlastirmasi zorunlu olur. Client uygulamalara Management API tokeni veya
`update:users` yetkisi verilmez.

## Taze kimlik dogrulama kaniti

Auth0 callback'indeki authorization code tek basina bir
`reauthenticationCredential` degildir. Code tek kullanimlidir ve onu ureteren
PKCE verifier, redirect URI, state ve OIDC nonce baglamiyla birlikte
dogrulanmalidir. Bu nedenle istemci ham `code` degerini hassas hesap
mutation'ina dogrudan vermez. Mevcut gorunur urunde bu akis hesap silme icin
kullanilir; `email_change` amaci capability kapali oldugu surece baslatilmaz.

Ortak akis su siniri kullanir:

1. Yetkili istemci `purpose`, izinli redirect URI ve `S256` code challenge ile
   `POST /api/account/reauthentication/start` cagirir.
2. Sunucu mevcut aktor tasimasindan web veya native Auth0 client'ini secer;
   tek kullanimlik request id, state ve nonce uretir. `max_age=0`,
   `prompt=login` ve offline access icermeyen scope ile authorization URL
   dondurur.
3. Sistem tarayicisi callback'inden sonra istemci request id, code, state,
   PKCE verifier ve redirect URI ile
   `POST /api/account/reauthentication/complete` cagirir.
4. Sunucu request kaydini, state'i, PKCE eslesmesini, Auth0 token imzasini,
   issuer/audience/client bagini, nonce'u, `auth_time` tazeligini ve provider
   subject'in mevcut `AccountActor` ile ayni oldugunu dogrular.
5. Basarili sonuc en cok 10 dakika yasayan, amaca ve kullaniciya bagli,
   tek kullanimlik bir Panelya `reauthenticationToken` dondurur. Sunucu yalniz
   token hash'ini saklar; authorization code, verifier, provider tokenlari ve
   subject log/audit/analytics'e yazilmaz.
6. Hassas mutation bu tokeni atomik olarak tuketir. Tekrar kullanim, farkli
   amac, farkli aktor veya sure asimi fail-closed reddedilir.

Reauthentication code exchange'i canli login oturumunu veya mobil
`TokenStore`u degistirmez; yeni refresh token istenmez ve donen gecici
provider tokenlari saklanmaz. Flutter'daki mevcut presentation-only
`beginSignIn() -> callback code -> FakeAccountRepository` demosu bu production
sozlesmesi degildir. HTTP adapter baglanmadan once tam start/complete akisini
kullanan repository sinirina gecilir.

## Oturum yonetimi

Production hedefi yalniz `bu cihazdan cikis` degil, iki platformda da ortak
aktif oturum envanteridir:

- web oturumlari D1 host-kapsamli session kayitlarindan,
- native oturumlar Auth0 refresh-token device credential kayitlarindan

sunucuda tek listeye donusturulur. Public cevap yalniz Panelya'nin opak oturum
kimligini, platformu, cihaz etiketini, `current` durumunu ve mevcut zaman
metadata'sini tasir; Auth0 credential id'si, token, IP veya provider subject
acilmaz.

Tekil iptal hedef web kaydini veya Auth0 device credential'ini kapatir. Toplu
iptal tum D1 public oturumlarini ve kullanicinin Panelya istemcisine ait Auth0
refresh grant/device credential kayitlarini kapatir. Mevcut JWT access tokeni
aninda geri cagrilamiyorsa en gec 15 dakikalik omrunu tamamlar; hassas
mutation'lar yerel `sessions_valid_after` benzeri iptal sinirini de denetler.

## Engellenen hesaplar

Engelleme Auth0 ozelligi degil Panelya domain verisidir. Web ve mobil:

- ayni engellenen hesap listesini gorur,
- engeli ayni idempotent API ile kaldirir,
- engelleme nedeniyle uygulanan iki yonlu yorum/yanit gorunurluk kurallarini
  ayni sunucu sonucundan alir.

Mobil istemci bu listeyi veya etkilesim grafini yerelde tahmin etmez.

## Hesabi silme

Production hesap silme yalniz D1 `users` satirini silmez. Kullanici mobil
uygulama icinden de silmeyi baslatabilir.

1. Kullaniciya silinecek/anonymize edilecek veri ve hukuken tutulacak istisna
   aciklanir; ikinci acik onay alinir.
2. Sistem tarayicisinda taze Auth0 kimlik dogrulamasi yapilir ve `auth_time`
   dogrulanir.
3. Panelya hesabi `deletion_pending` durumuna alinir; yeni yetkili istekler ve
   yeni oturumlar fail-closed reddedilir.
4. D1 web oturumlari ve Auth0 refresh oturumlari iptal edilir.
5. Server-side Management API, taze provider assertion'dan gecici olarak
   alinan Auth0 kullanici kimligini `delete:users` yetkisiyle siler. Ham
   provider subject D1'e kalici yazilmaz.
6. Panelya profil/veri temizligi idempotent bir is olarak tamamlanir.
   Yorumlar ve hukuki/audit kayitlari kesin KVKK/GDPR saklama politikasina
   gore silinir veya anonimlestirilir.

Islem hemen bitemiyorsa ortak API `202 Accepted` ve kullaniciya gosterilebilir
bir durum dondurur. Provider silinmis fakat D1 temizligi yarim kalmissa is
yerel Panelya kullanici kimligiyle tekrar denenebilir. Yalniz devre disi
birakma, tam silme yerine gecmez.

## Ortak API yuzeyi

Asagidaki ortak yuzeyin kesin istek/cevap sekilleri ve sentetik fixture'lari
contract-first teslimde `packages/contracts/schema.json`,
`packages/contracts/openapi.json` ve `packages/contracts/fixtures/account-*`
altinda tanimlanmistir. OpenAPI surumu `1.4.1`, geriye uyumlu response
`schemaVersion` degeri `1.0`dir. Bu teslim `main` dalina girip iki kalite isi
gecmeden mobil runtime entegrasyonu baslamaz.

| Islem | Ortak hedef |
| --- | --- |
| Hesap ozeti ve provider yetenekleri | `GET /api/account` |
| Profil | `PATCH /api/account/profile` |
| Taze dogrulama baslatma | `POST /api/account/reauthentication/start` |
| Taze dogrulama tamamlama | `POST /api/account/reauthentication/complete` |
| Sifre yenileme e-postasi | `POST /api/account/password-reset` |
| E-posta degisikligi | `POST /api/account/email-change` |
| Oturum listesi | `GET /api/account/sessions` |
| Tek oturum iptali | `DELETE /api/account/sessions/:id` |
| Diger/tum oturumlari kapatma | `POST /api/account/sessions/revoke` |
| Engellenen hesaplar | `GET /api/account/blocks` |
| Engelle / engeli kaldir | `PUT/DELETE /api/account/blocks/:userId` |
| Silme baslatma/durumu | `POST/GET /api/account/deletion` |

Hesap ozeti, kimlik turune gore en az `passwordAction`,
`emailChangeAction`, `sessionManagement` ve `deletionAction`
yeteneklerini dondurur. Web ve mobil calismayan aksiyonu placeholder olarak
gostermez.

## Teslim sirasi

1. Bu ADR `main` dalina girer.
2. Ortak schema/OpenAPI/fixture ve reauthentication kaniti contract-first
   kucuk PR olarak eklenir (bu teslim).
3. Web runtime, Auth0 Management API adapter'i, oturum birlestirme ve silme
   saga'sini uygular; mevcut yerel form uclari localhost adapteri kalir.
4. Flutter ayni fixture'larla codegen/repository/UI uygulamasini yapar.
5. Database ve Google kimligiyle web + Android + iOS manuel QA tamamlanir.

## 2026-07-30 web runtime uygulama notu

Ortak runtime `codex/account-runtime` dalinda uygulanmistir. Cookie ve Bearer
tasimalari tek `AccountActor`a iner; mobil icin ikinci hesap API'si acilmaz.
PKCE reauthentication kaniti JWE ile opak tutulur, D1 yalniz token hash'i ve
tek kullanim durumunu saklar. Auth0 Management API istemcisi server-only
client credentials kullanir; M2M secret, provider subject ve credential id
public cevaba/audit'e girmez.

Canli aktivasyon icin `AUTH0_MANAGEMENT_CLIENT_ID`,
`AUTH0_MANAGEMENT_CLIENT_SECRET`, `AUTH0_DATABASE_CONNECTION` ve en az 32
karakterlik `ACCOUNT_RUNTIME_SECRET` zorunludur. Web reauthentication icin
ayrica confidential BFF istemcisinin `AUTH0_WEB_CLIENT_ID`,
`AUTH0_WEB_CLIENT_SECRET`, exact `AUTH0_WEB_REDIRECT_URIS` ve
`AUTH0_WEB_LOGOUT_URIS` degerleri
provision edilmelidir. Bu degerler yokken ilgili hassas davranis 503 ile
fail-closed kalir.

Web uygulamasinda normal giris callback'i
`https://<public-domain>/api/auth/web/callback`, hesap e-posta/silme
reauthentication callback'i ise
`https://<public-domain>/account/reauthentication/callback` olur. Ikisi hem Auth0
Allowed Callback URLs hem de `AUTH0_WEB_REDIRECT_URIS` exact allowlist'inde yer
alir. Reauthentication istemcisi verifier ve bekleyen mutation bilgisini yalniz
ayni sekmenin `sessionStorage` alaninda tutar; authorization code callback
basladiginda adres cubugundan silinir, provider tokeni tarayici depolamasina
yazilmaz.

Auth0 Management API'ye baglanan M2M uygulamasina yalniz su izinler verilir:
`read:users`, `update:users`, `delete:users`, `read:device_credentials` ve
`delete:device_credentials`. `users-by-email` aramasi `read:users`, e-posta
degisikligi `update:users`, kimlik silme `delete:users`, native refresh-token
envanteri `read:device_credentials` ve tekil/toplu native oturum iptali
`delete:device_credentials` kullanir. Daha genis tenant yonetim izinleri
verilmez.

Canli smoke testinden once Git disi `.dev.vars` yapilandirmasi
`npm run auth0:preflight` ile kontrol edilir. Bu komut secret degerlerini
yazdirmaz; yalniz zorunlu alanlarin varligini, en az uzunluk sinirini, mobile
callback'i, iki exact web callback'ini, logout origin'ini ve Management API
audience seklini denetler. Eksik kontrolde sifir olmayan kodla kapanir. Farkli
bir Git disi dosya veya origin icin
`npm run auth0:preflight -- --env-file <dosya> --origin <origin>` kullanilir.
Dashboard provisioning ve canli iki-provider QA sirasi
`docs/auth0-live-provisioning.md` runbook'unda tutulur.

Auth0 device credential API'si mevcut access tokeni belirli refresh
credential id'sine baglamadigi icin native envanter kayitlari bu teslimde
guvenli bicimde listelenip iptal edilir fakat `current` isareti tahmin
edilmez. Gateway'in access-token/refresh-family oturum kaydi eklenmeden
production QA'da bu alan tamamlanmis sayilmaz. Envanter hem klasik
`refresh_token` hem de ADR-039 ile zorunlu tutulan donen
`rotating_refresh_token` credential tiplerini kapsar.

## 2026-08-02 native `scope=others` kararı — sağlayıcı sınırı kanıtlandı (ADR-054)

Yukarıdaki "Auth0 device credential API'si mevcut access tokeni belirli
refresh credential id'sine bağlamadığı için ... `current` işareti tahmin
edilmez" notu bu turda kod ve Auth0 resmi dokümantasyonu okunarak
doğrulanmış, kapatılamayan bir sağlayıcı sınırı olarak kesinleştirilmiştir.
Sahte/tahmini bir eşleme eklenmedi; mobilde `scope=others` 503
`service_unavailable` fail-closed dönmeye devam eder.

### Kod incelemesi — sunucu bugün ne biliyor, ne bilmiyor

- `app/lib/auth0-runtime.ts` → `exchangeMobileToken`: mobil token gateway'i
  Auth0'nun `/oauth/token` cevabındaki `access_token`/`refresh_token`
  çiftini doğrulayıp (JWKS) olduğu gibi istemciye iletir. Hiçbir refresh
  token veya cihaz kimliği D1'de kalıcı bir "bu oturum benim" kaydına
  bağlanmaz; ADR-039 zaten bunu kasıtlı olarak istemiyor ("gateway ...
  tokenlari kalici olarak saklamaz").
- `app/lib/account-sessions.ts` → `listAccountSessions`/`nativeSessionContext`:
  native oturum envanteri tamamen Auth0 Management API
  `GET /api/v2/device-credentials` listesinden gelir. Kod içinde açık yorum:
  *"Auth0 access tokens do not expose the originating device credential
  id"* — bu yüzden native satırların `current` alanı **her zaman**
  `false`'dur; sunucu hangi satırın "bu isteği yapan cihaz" olduğunu bilmez.
- `app/lib/account-sessions.ts` → `revokeAccountSessions`: `scope === "others"
  && actor.transport === "mobile"` kontrolü fonksiyonun İLK satırıdır — herhangi
  bir `deleteAuth0DeviceCredential` çağrısından önce 503 döner. Bu, "hangi
  cihazın benim olduğunu bilmediğim sürece TÜM native cihazları 'diğerleri'
  sayıp silme" riskini baştan keser.
- `app/lib/auth0-management.ts` → `listAuth0DeviceCredentials`: Management
  API'den dönen alanlar yalnız `id`, `device_name`, `type`, `created_at`,
  `last_used_at`'tır; bir access/refresh token örneğiyle eşleşen hiçbir alan
  yoktur.
- Mobil istemci zaten dürüst davranıyor: `apps/mobile/lib/features/account/
  presentation/sessions_screen.dart` sınıf dokümantasyonu ve
  `apps/mobile/test/features/account/presentation/sessions_screen_test.dart`
  içindeki "BİLİNEN SINIR" testi, sunucunun 503 döndüğü durumda ekranın
  sahte başarı üretmediğini, listenin değişmediğini ve yerel çıkışın
  TETİKLENMEDİĞİNİ doğrular. Sunucu tarafı statik kanıt
  `tests/account-runtime.test.mjs` → "oturum toplu iptali mevcut native cihaz
  eşlenmeden başarılı görünmez" testinde korunur.

### Auth0 resmi dokümantasyon bulguları (kaynak URL ile doğrulandı)

- `GET /api/v2/device-credentials` yanıtı yalnız `id`, `device_name`,
  `device_id`, `type`, `user_id`, `client_id` alanlarını taşır ve
  `device_id` alanı `refresh_token`/`rotating_refresh_token` türleri için
  **zaten doldurulmaz**; hiçbir alan bir access/refresh token örneğiyle
  eşleşmez.
  https://auth0.com/docs/api/management/v2/device-credentials/get-device-credentials
- Refresh token rotasyonu dokümantasyonu, rotasyonun aynı device-credential
  kaydını mı güncellediğini yoksa yeni bir kayıt mı oluşturduğunu
  belgelemez; yalnız "reuse detection tüm aileyi iptal eder" kavramsal
  ilişkisinden bahseder, teknik bir aile/oturum kimliği tanımlamaz.
  https://auth0.com/docs/secure/tokens/refresh-tokens/refresh-token-rotation
  https://auth0.com/docs/secure/tokens/refresh-tokens/configure-refresh-token-rotation
- `sid` (session id) claim'i yalnız ID token / back-channel logout amacıyla
  belgelenir ("the Auth0 tenant adds the `sid` to the ID token"); access
  token'da bulunduğu belgelenmez. Mobil akış zaten ID token'ı API
  yetkilendirmesinde KABUL ETMEZ (ADR-039), dolayısıyla bu claim mobil
  bearer isteklerinde kullanılabilir bir sinyal değildir.
  https://auth0.com/docs/authenticate/login/logout/back-channel-logout
- Authorize (PKCE) ve refresh-token uç noktalarının resmi parametre
  listelerinde, istemcinin ayarlayıp sonucun device-credential kaydına
  yansıyacağı bir "device id/name" parametresi YOKTUR; `device_name`
  Auth0 tarafından otomatik türetilir, istemci tarafından belirlenemez.
  https://auth0.com/docs/api/authentication/authorization-code-flow-with-pkce/authorize-with-pkce
  https://auth0.com/docs/api/authentication/refresh-token/refresh-token

### Karar

Mevcut mimaride (gateway Auth0 tokenlarını olduğu gibi ileten stateless bir
proxy) `scope=others` için "hangi native oturum BENİM" sorusunun güvenli,
sağlayıcı tarafından desteklenen ve yarışsız (race-free) bir cevabı
**yoktur**. Diffing/heuristik bir eşleme (ör. Auth0 Management API'den
oturum açılışında "yeni oluşan" device-credential'ı önce/sonra
karşılaştırarak tahmin etmek) kasıtlı olarak EKLENMEDİ: bu, eşzamanlı
girişlerde yarış durumuna açıktır, Auth0 tarafından belgelenmemiş/
desteklenmemiştir ve görev talimatının yasakladığı türde bir "tahmin"dir.
503 fail-closed davranışı KORUNUR; gizlenmez.

### Desteklenebilir gelecek alternatifleri (karar kaydı, bu teslimde UYGULANMADI)

1. **Gateway kendi opak refresh-token broker'lığını üstlenir**: mobil
   istemciye Auth0'ın ham refresh token'ı hiç verilmez; gateway Auth0 ile
   kendi refresh döngüsünü sunucu tarafında yürütüp istemciye yalnız kendi
   ürettiği opak bir "Panelya mobil refresh credential" verir ve D1'de
   `session_id ↔ mevcut Auth0 refresh token` eşlemesini (yalnız hash olarak
   değil, gateway'in Auth0'a tekrar refresh atabilmesi için gerçek değeri de)
   tutar. Bu durumda "hangi oturum benim" sorusu tamamen Panelya'nın kendi
   kaydında, sağlayıcıya bağımlı olmadan cevaplanır. **Bu, ADR-039'un
   "gateway tokenları kalıcı olarak saklamaz" ilkesini kasıtlı olarak
   değiştirir** — ayrı bir ADR, tehdit modeli incelemesi (sunucuda saklanan
   refresh token'ın sızması artık tüm oturumları etkiler) ve migration
   gerektirir; bu göreve dahil değildir.
2. **Auth0 Action ile access token'a custom claim eklemek**: Auth0
   Actions'ın `post-login` tetikleyicisi refresh token exchange'lerinde de
   çalışır ve `api.accessToken.setCustomClaim()` ile access token'a özel
   alan eklenebildiği resmi olarak belgelenir
   (https://auth0.com/docs/customize/actions/flows-and-triggers/login-flow).
   Ancak Action'ın konteksti içinde Auth0'ın kendi iç `device_credential.id`
   değerine erişim resmi olarak belgelenmemiştir; bu yüzden Action'ın
   ekleyebileceği tek güvenilir claim, GİRİŞ ANINDA gateway'in ürettiği
   KENDİ opak session id'si olurdu — ki bu yine (1) numaralı değişikliği
   (gateway'in kendi oturum kaydını tutması) önkoşul yapar, tek başına
   çözüm değildir.
3. **Cihaz kaydı (device registration)**: istemci ilk girişte kendi
   ürettiği rastgele bir kurulum kimliğini `/api/account/*` üzerinden ayrı
   bir Panelya-yerel tabloya kaydeder ve sonraki her istekte bu kimliği bir
   header olarak gönderir. Bu, istemcinin KENDİ beyanına dayanır (sunucu
   tarafından kriptografik olarak doğrulanmaz); ele geçirilmiş bir cihaz
   kendi kimliğini yanlış beyan ederek "diğerleri" temizliğinden kaçabilir.
   Tehdit modeli (çalınan refresh token'ın devre dışı bırakılması) için
   YETERSİZDİR, yalnız (1) numaralı çözümle birlikte (yani sunucu tarafı
   session tablosu zaten varken) ek bir kullanıcı dostu etiket olarak
   anlamlıdır.

Üç alternatif de mimari kapsam ve güvenlik incelemesi gerektirdiği için bu
teslimde uygulanmadı; 503 fail-closed doğru ve dürüst davranış olarak kalır.

## Resmi dayanaklar

- Auth0 change-password endpoint:
  https://auth0.com/docs/api/authentication/change-password/change-password
- Auth0 Management API user update:
  https://auth0.com/docs/api/management/v2/users/patch-users-by-id
- Auth0 Management API user delete:
  https://auth0.com/docs/api/management/v2/users/delete-users-by-id
- Auth0 Management API user izinleri:
  https://auth0.com/docs/manage-users/user-accounts/manage-users-using-the-management-api
- Auth0 device credential listeleme ve `read:device_credentials`:
  https://auth0.com/docs/api/management/v2/device-credentials/get-device-credentials
- Auth0 device credential silme ve `delete:device_credentials`:
  https://auth0.com/docs/api/management/v2/device-credentials/delete-device-credentials-by-id
- Auth0 refresh-token/device credential iptali:
  https://auth0.com/docs/secure/tokens/refresh-tokens/revoke-refresh-tokens
- Auth0 taze kimlik dogrulama:
  https://auth0.com/docs/authenticate/login/max-age-reauthentication
- Apple uygulama ici hesap silme:
  https://developer.apple.com/support/offering-account-deletion-in-your-app/
- Auth0 refresh token rotasyonu (kavram):
  https://auth0.com/docs/secure/tokens/refresh-tokens/refresh-token-rotation
- Auth0 `sid` claim ve back-channel logout:
  https://auth0.com/docs/authenticate/login/logout/back-channel-logout
- Auth0 Actions `post-login`/refresh token exchange tetikleyicisi:
  https://auth0.com/docs/customize/actions/flows-and-triggers/login-flow
- Auth0 authorize (PKCE) parametreleri:
  https://auth0.com/docs/api/authentication/authorization-code-flow-with-pkce/authorize-with-pkce
- Auth0 refresh token grant parametreleri:
  https://auth0.com/docs/api/authentication/refresh-token/refresh-token
