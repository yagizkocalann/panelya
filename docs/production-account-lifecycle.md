# Production hesap yasam dongusu (ADR-047)

## Karar

`Hesabim`, web ve Flutter icin ayni Panelya hesap merkezidir. Platformlar ayni
ekran bilesenlerini kullanmak zorunda degildir; ancak ayni yetenekleri, ayni
sunucu kurallarini ve `packages/contracts` altindaki ayni JSON sozlesmesini
kullanir.

Standart hesap kapsami iki platformda da sunlari icerir:

1. hesap bilgisi ve profil,
2. e-posta yonetimi,
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

E-posta, Auth0 kimliginin ozelligidir; D1 production'da bagimsiz ana kaynak
olamaz.

- Auth0 database kimliginde degisiklikten once sistem tarayicisinda taze
  kimlik dogrulama zorunludur. Yetkilendirme istegi `max_age=0` kullanir ve
  sunucu, donen `auth_time` kanitini dogrular.
- Degisiklik yalniz server-side Auth0 Management API istemcisiyle yapilir.
  Yeni adres dogrulanmamis baslar ve dogrulama e-postasi gonderilir.
- D1 e-posta degeri Auth0'daki dogrulanmis claim gorulmeden yeni adresi
  authoritative kabul etmez.
- Sosyal kimlikte e-posta provider tarafindan yonetiliyorsa Panelya alani
  salt okunur olur; istemci bunu acikca anlatir ve calismayan form gostermez.

Client uygulamalara Management API tokeni veya `update:users` yetkisi
verilmez.

## Taze kimlik dogrulama kaniti

Auth0 callback'indeki authorization code tek basina bir
`reauthenticationCredential` degildir. Code tek kullanimlidir ve onu ureteren
PKCE verifier, redirect URI, state ve OIDC nonce baglamiyla birlikte
dogrulanmalidir. Bu nedenle istemci ham `code` degerini e-posta degisikligi
veya hesap silme mutation'ina dogrudan vermez.

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
altinda tanimlanmistir. OpenAPI surumu `1.4.0`, geriye uyumlu response
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

## Resmi dayanaklar

- Auth0 change-password endpoint:
  https://auth0.com/docs/api/authentication/change-password/change-password
- Auth0 Management API user update:
  https://auth0.com/docs/api/management/v2/users/patch-users-by-id
- Auth0 Management API user delete:
  https://auth0.com/docs/api/management/v2/users/delete-users-by-id
- Auth0 refresh-token/device credential iptali:
  https://auth0.com/docs/secure/tokens/refresh-tokens/revoke-refresh-tokens
- Auth0 taze kimlik dogrulama:
  https://auth0.com/docs/authenticate/login/max-age-reauthentication
- Apple uygulama ici hesap silme:
  https://developer.apple.com/support/offering-account-deletion-in-your-app/
