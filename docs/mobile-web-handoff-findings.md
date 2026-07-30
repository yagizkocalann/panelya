# Mobil → Web devir bulguları

Bu doküman, mobil tarafın canlı QA turlarında ortaya çıkardığı ve
**çözümü web/altyapı tarafında olan** açık maddeleri toplar. Mobil
tarafta yapılabilecek işler zaten yapılıp `codex/mobile` dalına
alınmıştır; buradakiler mobil koddan kapatılamaz.

Değer taşımayan hiçbir varsayım yazılmadı: her madde canlı bir turda
gözlendi ve nasıl gözlendiği belirtildi.

## 1. Eksik runtime yapılandırması (iki akış bloke)

Aşağıdaki uçlar yerel ortamda 503 fail-closed dönüyor. Mobil istemci bunu
doğru ele alıyor (sunucunun kendi mesajını gösteriyor, sahte başarı
üretmiyor), ama akışlar **hiçbir platformda doğrulanamadı**.

| Akış | Eksik değişken adları |
| --- | --- |
| `GET /api/account/sessions` (ve oturum kapatma) | `ACCOUNT_RUNTIME_SECRET` |
| `POST /api/account/password-reset`, e-posta değişikliği | `AUTH0_MANAGEMENT_CLIENT_ID`, `AUTH0_MANAGEMENT_CLIENT_SECRET`, `AUTH0_MANAGEMENT_AUDIENCE` |

Yalnız değişken **adları** listelenmiştir; değerler bu dokümana veya
herhangi bir loga yazılmaz.

Gözlem: iOS canlı turunda "Aktif oturumlar" ekranı sunucunun
`Hesap çalışma anahtarı yapılandırılmamış.` mesajını gösterdi.

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

Ayrıca `android/app/build.gradle.kts` release'i hâlâ **debug
anahtarıyla** imzalıyor (dosyada `TODO` olarak duruyor); mağaza yayını
öncesi gerçek imza yapılandırması gerekiyor.
