# Mobil teslim raporu — 30 Temmuz 2026

**Dal:** `codex/mobile`
**HEAD:** `1c2037b4013ff2e5cd2b35c6415d96d8e27c6eae`
**Başlangıç:** `origin/main@207b690` merge edildi (rebase/force-push yok)
**`main`e merge edilmedi.**

Bu tur, ADR-047 hesap entegrasyonunun canlı doğrulamasıyla başladı ve
canlı QA'nın ortaya çıkardığı sorunların düzeltilmesiyle sürdü. Aşağıdaki
her madde **gözlenerek** bulundu; hiçbiri tahmine dayanmıyor ve her biri
nasıl bulunduğuyla birlikte yazıldı.

## Özet

| Ölçüm | Başlangıç | Sonuç |
| --- | --- | --- |
| Flutter testleri | 487 | **533** |
| Kapsam (generated hariç) | %91.1 | **%93.1** |
| `http_account_repository.dart` kapsamı | %48.1 | **%100** |
| İlk kare (Pixel 8, profile) | 993 ms | **486 ms** |
| Bulunan ve düzeltilen sorun | — | **9** |

Tüm kalite kapıları yeşil: `flutter analyze` temiz, `flutter test` 533/533,
kök `npm test` 61/61, `npm run lint` temiz, contract codegen deterministik
(`1738f421a6ae…` iki koşuda aynı).

---

## A. Canlı QA'da bulunan hatalar

### A1. Access token yenilenmiyordu

**Nasıl bulundu:** Android canlı QA, hesap ekranında
"Access token süresi dolmuş." SnackBar'ı.

`HttpAccountRepository` `TokenStore`'daki access token'ı gönderiyor ama
süresi dolduğunda yenilemiyordu. Hesap uçları 15 dakikalık access token
kullandığı için **girişten ~15 dk sonra TÜM hesap işlemleri kırılıyordu**.
Bayrak açıldığında her kullanıcının karşılaşacağı bir kırılmaydı.

Düzeltme: `_guard` artık sunucunun `not_authenticated` +
`reauthenticate: true` yanıtını tanıyıp bir kez `refresh()` ediyor ve
isteği tekrarlıyor. Yenileme başarısızsa **orijinal** sunucu hatası yüzeye
çıkıyor; sahte başarı üretilmiyor. (`2179d20`)

### A2. Yükleme hatalarında sunucunun mesajı gizleniyordu

**Nasıl bulundu:** Android canlı QA — sunucu 503 + `errorDescription`
dönerken ekranda genel "Beklenmeyen bir hata oluştu." görünüyordu.

Sözleşmenin yapılandırılmış hata gövdesi elimizdeyken kullanıcıdan gerçek
sebebi saklamak ADR-010 ile çelişiyor. `accountErrorMessage` yardımcısı
eklendi, altı hesap ekranının yükleme-hatası yolu buna bağlandı.
(`cdeebc9`)

### A3. iOS push aboneliği sessizce kayboluyordu

**Nasıl bulundu:** iOS canlı QA — uygulama **her açılışta**
`Unhandled Exception: [firebase_messaging/apns-token-not-set]` düşürüyordu.

Üç ayrı kusur çıktı:

1. `bootstrap` aboneliği hiç korumuyordu.
2. iOS'ta APNs kaydı açılıştan *sonra* asenkron tamamlanır; `bootstrap`
   aboneliği hemen çağırdığı için ilk açılışta token henüz gelmemiş
   oluyordu. Yani **gerçek cihazda da** uygulamayı yeni kuran bir iOS
   kullanıcısı `panelya-new-episodes` konusuna abone olamıyordu.
3. Bildirimler ekranının hem açma hem **kapatma** yolu korumasızdı
   (`unsubscribeFromTopic` de aynı hatayı fırlatıyor) — kullanıcı anahtarı
   kapatıyor, hiçbir şey olmuyor, mesaj da görünmüyordu.

Düzeltme: `waitForApnsToken` ile token sınırlı süre (8 × 250 ms) yoklanıp
işlem bir kez tekrarlanıyor. **`Platform.isIOS` dallanması yok** —
Android'de `getAPNSToken()` her zaman `null` döndüğü için token beklemek
Android'i yanlışlıkla bloklardı; bunun yerine `apns-token-not-set` hata
kodu üzerinden ele alınıyor. (`a971555`)

### A4. Erişilebilirlik yazı boyutunda hero başlığı kırpılıyordu

**Nasıl bulundu:** iOS canlı QA, `content_size accessibility-extra-extra-
extra-large`.

Keşif ekranındaki hero kartının başlığı ("Gece Vardiyası") üstten
kırpılıyor, kullanıcı seri adını okuyamıyordu. Sabit `AspectRatio(4/5)` +
`Positioned(bottom:)` kombinasyonu, metin büyüyünce sütunu kartın dışına
taşırıyor ve `ClipRRect` kırpıyordu.

**Mevcut `OverflowWatcher` testleri bunu yakalayamazdı:** sabit
`AspectRatio` içeriği taşırdığında `RenderFlex` hatası *düşmez*, kırpma
sessizce olur. Yeni testler bu yüzden geometriyi doğrudan ölçüyor.

Düzeltme: `LayoutBuilder` + `ConstrainedBox(minHeight: genişlik × 5/4)`.
Kart 4:5'ten kısa olmuyor ama gerekirse uzuyor. (`8621047`)

### A5. Kalıcı hatalarda 11 boşuna istek + 25 sn spinner

**Nasıl bulundu:** iOS canlı QA — "Aktif oturumlar" ekranı uzun süre
"yükleniyor" gösterdi, sunucu logunda 11 ardışık 503 sayıldı.

Sebep Riverpod 3'ün varsayılan `retry` davranışı
(`ProviderContainer.defaultRetry`, `maxRetries = 10`, 200 ms → 6400 ms
backoff). Log'daki 11 sayısı bu sabitle birebir eşleşti. Ancak sunucu
sözleşmeye uygun yapılandırılmış bir hata gövdesi döndüğünde sonuç
deterministiktir — tekrar denemek onu başarılı yapmaz.

Düzeltme: `accountProviderRetry` politikası. Sunucu **karar verdiyse**
denenmez (kullanıcı hatayı hemen görür, tekrar deneme kararı "Tekrar dene"
butonuyla kendisine kalır); ağ/parse hatası gerçekten geçici olduğu için
Riverpod varsayılanı korunur. **Canlı sonuç: 11 istek → 1.** (`dbe9549`)

### A6–A9. UI geri çağrımlarındaki korumasız async çağrılar

**Nasıl bulundu:** A3 ve A5'in aynı kalıptan çıktığını fark edip kalıbı
tüm kod tabanında taradım (`Future<void> _handler(` sayısı vs `try {`
sayısı). Üç korumasız yol daha çıktı.

- **A6 — `logout()` ağ hatasında fırlatıyordu.** Mevcut catch yalnız
  `AuthApiException`'ı yutuyordu; zaman aşımı/soket/transport hataları
  `NetworkException` olur ve yakalanmıyordu. Oysa hemen üstündeki ADR-039
  yorumu "revoke başarısız olsa bile yerel oturum temizlenir" diyor — kod
  kendi belgelenmiş niyetiyle çelişiyordu.
- **A7 — `AccountHomeScreen._signOut`** meşgul bayrağını `finally`
  olmadan set ediyordu. Hata durumunda buton **kalıcı olarak spinner'da
  kilitleniyor**, kullanıcı ne çıkabiliyor ne tekrar deneyebiliyordu.
- **A8 — `SessionsScreen._signOutLocally`** hata durumunda kullanıcı hâlâ
  giriş yapmış olduğu hâlde ana sayfaya gidiyordu (çıkmış gibi
  gösteriliyordu).
- **A9 — `DownloadsScreen._confirmDeleteAll`** döngüdeki ilk hata döngüyü
  kesiyordu; kalan bölümler silinmeden, mesaj olmadan "hiçbir şey
  olmamış" gibi görünüyordu.

Hepsi aynı ilkeyle düzeltildi: meşgul bayrağı `finally` ile mutlaka
sıfırlanır, kısmi/başarısız işlem sahte başarı olarak gösterilmez, sebep
dürüstçe bildirilir. (`4239e89`)

---

## B. Performans

**Ölçüm yöntemi:** `flutter run --profile --trace-startup` (Pixel 8
emülatörü), ardından sebebi bulmak için `bootstrap`'a geçici zamanlama
konuldu.

```
binding          1 ms
prefs            4 ms
pathProvider     6 ms
firebase       411 ms   <-- tek başına 405 ms
```

`Firebase.initializeApp()` `runApp`'ten **önce** await ediliyordu. İlk
kare, arayüzün hiç ihtiyaç duymadığı bir başlatma için ~405 ms
bekliyordu; Firebase yalnız push teslimatı için gerekli.

Başlatma artık `runApp` ile paralel yürüyor.
`DeferredPushNotificationRepository` sarmalayıcısı, hazır olmadan gelen
çağrıları (kullanıcı hızlı davranıp Bildirimler'i açarsa ya da deep-link
doğrudan oraya götürürse) sessizce bekletiyor.

| Ölçüm | Önce | Sonra |
| --- | --- | --- |
| `timeToFirstFrame` | 993 ms | **486 ms** (−507 ms, %51) |
| `timeToFirstFrameRasterized` | 1019 ms | **511 ms** |

Init yolu değiştiği için push iki platformda da canlı doğrulandı:
Android temiz kurulumda `Topic subscribe … succeeded`, iOS'ta yakalanmamış
hata 0. (`8ec41df`)

---

## C. Güvenlik

GitHub secret scanning'in açtığı iki Google API Key uyarısı üzerine
Firebase istemci yapılandırma dosyaları Git takibinden çıkarıldı
(`git rm --cached`, yerel diskten silinmeden). Kök `.gitignore`'a tam
yollar eklendi, yeni clone kurulumu için `docs/mobile-firebase-config.md`
yazıldı. History rewrite **yapılmadı**; anahtarlar eski commit'lerde
okunabilir kalıyor ve ancak Google/Firebase Console'da döndürülüp
uygulama/API kısıtları verildikten sonra kapanır. (`c1d65e6`)

Kısıt eklendikten sonra aynı debug APK ile yeniden doğrulandı: Firebase
başlatma, bildirim izni, `panelya-new-episodes` topic aboneliği ve
Installations `Status = 3` (REGISTERED) — API key reddi sıfır. Gerçek FCM
teslimi ve deep-link açılışı `FCM_PROJECT_ID` / `FCM_CLIENT_EMAIL` /
`FCM_PRIVATE_KEY` sağlanmadığı için doğrulanamadı.

---

## D. Test kapsamı

Kapsam ölçüldüğünde `http_account_repository.dart` **%48.1** çıktı:
12 metodun 8'inin hiç testi yoktu. Bu metotlar ortak sözleşmeye göre HTTP
yolu ve gövdesi kuruyor; yanlış bir alan adı yalnızca canlıda görülürdü —
ve bu uçların bir kısmı canlıda **da** görülemiyor (`sessions`,
`password-reset` yerel ortamda 503 fail-closed dönüyor).

11 test eklendi; her biri metodu, yolu ve gövdeyi kilitliyor. Yol
kodlaması ayrıca doğrulanıyor: oturum/kullanıcı kimliğindeki `/` ve boşluk
kaçılmalı, aksi hâlde istek başka bir uca giderdi.

Yanıt gövdeleri **tahmin edilmiyor** — ortak
`packages/contracts/fixtures/account-*.v1.json` dosyalarından okunuyor,
böylece sözleşme değişirse testler kendiliğinden yakalar. (İlk denemede
gövdeleri tahmin etmiştim ve dördü birden kırmızıya düştü; gerçek şekiller
`accepted` ve `accounts` alanlarını kullanıyor.)

Sonuç: adapter %48.1 → **%100**, genel %91.1 → **%93.1**. (`a9987cb`)

---

## E. Yayın hazırlığı

Release build denemesi bir dağıtım sorunu ortaya çıkardı:

| Artefakt | Boyut |
| --- | --- |
| `flutter build apk` (tek APK) | **55.9 MB** — kullanıcı bunu indirir |
| `--split-per-abi`, arm64 | 19.9 MB — cihazın gerçekten kullandığı |
| `--split-per-abi`, armeabi-v7a | 17.4 MB |
| `--split-per-abi`, x86_64 | 21.3 MB — **yalnız emülatör** |

55.9 MB'ın 51.9 MB'ı native kütüphane; bir cihaz bunlardan yalnız birini
çalıştırıyor. Tek APK dağıtmak arm64 kullanıcısına **36 MB fazladan
indirtiyor (%64 israf)**. README'ye ölçümlerle `appbundle` /
`--split-per-abi` yönergesi eklendi.

iOS release build temiz geçti (20.5 MB; iOS zaten mimari başına dağıtır).

`android/app/build.gradle.kts` release'i hâlâ **debug anahtarıyla**
imzalıyor (dosyada `TODO`); mağaza yayını öncesi gerçek imza gerekiyor.
(`27568aa`)

---

## F. İşlevsel eksikler

Web ile mobil rota yüzeyi karşılaştırıldı.

**F1 — Mağaza şartı: gizlilik politikası bağlantısı yoktu.** Hem App Store
(Review Guideline 5.1.1) hem Play Console, hesap açan ve kişisel veri
işleyen uygulamalarda gizlilik politikasının uygulama içinden erişilebilir
olmasını ister. Bu sayfalar yalnız web footer'ında vardı. `LegalLinks`
eklendi (Gizlilik / Kullanım koşulları / Telif bildirimi, yollar web
footer'ıyla aynı), Hesabım ekranının altında giriş durumundan bağımsız
görünüyor. Sistem tarayıcısında açılıyor. `WEB_ORIGIN` define'ı eklendi;
verilmezse `API_ORIGIN`'e düşüyor — ayrı domain kullanılacaksa açıkça
verilmeli, tahmin yapılmıyor.

**F2 — Var olmayan bir özellik vaat ediliyordu.** Giriş ekranı
"kütüphaneni ve favorilerini senkronize et" diyordu; mobilde kütüphane
ekranı yok ve ortak sözleşmede kütüphane yüzeyi tanımlı değil. Metin
gerçeğe çekildi. Ayrıntı ve web'den beklenen için bkz.
`mobile-web-handoff-findings.md` madde 8. (`1c2037b`)

---

## G. Canlı QA kapsamı

**Android** (Pixel 8 API 34): giriş, `GET /api/account`, profil
güncelleme, silme özeti, engellenenler, reauth start + iptal, push topic
aboneliği/kaldırma, FCM teslimi, deep-link açılışı.

**iOS** (iPhone 15 Pro simulator): giriş zinciri, altı hesap ekranı,
profil güncelleme, **Keychain'den oturum geri yükleme** (Android'in
EncryptedSharedPreferences yolundan ayrı kod, ilk kez doğrulandı), silme
özeti, engellenenler, reauth start + iptal, deep-link, çevrimdışı indirme
+ sandbox'a yazma + sunucu kapalıyken okuma + indirilmemiş bölümün dürüst
hatası + toplu silme, AX yazı boyutunda yerleşim.

**Doğrulanamayanlar:** hesap silme (disposable hesap yok, geri alınamaz),
oturum envanteri ve şifre yenileme (503 — eksik değişkenler),
iOS APNs push (simulator APNs token alamaz).

Ayrıntılı engel listesi: `mobile-web-handoff-findings.md`.
