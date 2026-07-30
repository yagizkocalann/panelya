# Mobil uygulama devralma notu

## Başlangıç ilkesi

Mobil uygulama mevcut web arayüzünü taşımaya çalışmaz. Flutter ayrı bir istemci olur (ADR-019); web uygulamasının API sözleşmelerini ve domain kurallarını kullanır. Dart modelleri `schemaVersion` taşıyan JSON sözleşmesinden türetilir; TypeScript kod paylaşımı hedeflenmez.

İskelet, Novel-Project uygulamasının kanıtlanmış kalıplarından devralınır: feature-first dizin yapısı, Riverpod state yönetimi, go_router (deep-link hazır), design token teması ve `env/` dart-define katmanı. Novel'in Firebase veri katmanı taşınmaz; aynı repository interface deseninin arkasına Panelya REST client'ı yazılır. Episode player'ı (dikey video pager) kullanılmaz; webtoon okuyucusu kesintisiz dikey panel scroll'u olarak sıfırdan uygulanır.

Mobil geliştirme `codex/mobile` branch'inde ve `apps/mobile` dizininde başlar. Web uygulamasını `apps/web` altına taşıyan monorepo refactor'u mobil başlangıcının ön koşulu değildir; bu değişiklik iki branch arasında gereksiz çatışma yaratmamak için ayrıca planlanır.

## İlk mobil kapsam

1. Keşif ve katalog
2. Seri detay ve bölüm listesi
3. Dikey okuyucu
4. API hata/boş/yükleniyor durumları
5. Deep-link taslağı

Hesap kimlik dogrulamasi ADR-039 ile canli Auth0 testinden gecmistir. Standart
`Hesabim` kapsami ADR-047'ye gore profil, e-posta/sifre yonetimi, aktif
oturumlar, engellenen hesaplar ve hesap silmeyi iki platformda da icerir.
Flutter bu mutasyonlari mevcut yerel web form endpoint'lerinden kopyalamaz.
ADR-047 contract-first OpenAPI `1.4.1` teslimi `main` dalindadir; mobil
fixture/codegen ve `HttpAccountRepository` entegrasyonuna baslamistir.
Cevrimdisi okuma sonraki mobil fazda kalir. Yeni bolum push
bildiriminin sunucu siniri ADR-046 ile hazirdir.

## Mevcut API başlangıç noktaları

- `GET /api/discovery`
- `GET /api/catalog`
- `GET /api/series/:slug`
- `GET /api/series/:slug/episodes/:episodeSlug`
- `POST /api/auth/*`
- `GET/POST /api/library/*`
- `POST /api/progress`

Mobil istemci D1 veya R2'ye doğrudan bağlanmaz. Bütün veri erişimi web deployment'ındaki API sınırından geçer.

## Kimlik doğrulama uyarısı

Mevcut yerel auth akışı HttpOnly web cookie'sine dayanır ve production kimlik
sağlayıcısı değildir. Mobil branch bu cookie davranışını kalıcı sözleşme kabul
etmemelidir. ADR-039 production sağlayıcısını Auth0, mobil akışı sistem
tarayıcılı Authorization Code + PKCE olarak seçer; ortak contract ve mobil
runtime gateway/JWKS entegrasyonu tamamlanmistir.

2026-07-29 itibariyla Android canli Auth0 callback, token exchange, refresh ve
revoke turu tamamlanmistir. Siradaki kimlik isi login transportu degil,
ADR-047 ortak hesap yasam dongusudur.

## Standart Hesabim kapsami (ADR-047)

Web ve Flutter asagidaki urun yeteneklerinde parite saglar:

1. hesap/profil ozeti,
2. Auth0 database hesabinda e-posta ile sifre yenileme; sosyal hesapta
   provider-yonetimli aciklama,
3. provider destekliyorsa taze Auth0 dogrulamali e-posta degisikligi,
4. web ve native aktif oturum listesi ile tekil/toplu iptal,
5. engellenen hesaplar ve engeli kaldirma,
6. uygulama icinden baslatilabilen, Auth0 kimligi ile Panelya verisini birlikte
   ele alan hesap silme.

Mobil icin ayri `/api/account/mobile/*` gateway'i yoktur. Ortak
`/api/account/*` JSON uclari web cookie veya mobil Bearer kabul eder.
`/api/auth/mobile/*` yalniz OAuth code/refresh/revoke tasimasidir.

Mevcut local PBKDF2 `/api/account/password`, `/api/account/email` ve
`/api/account/delete` form davranislarini Flutter kopyalamaz. Kesin endpoint
istek/cevaplari, reauthentication kaniti ve fixture'lar
`packages/contracts` altinda `main` dalina girmistir. Mobil adapter yalniz bu
contract'i kullanir; sahte basarili mutation veya tiklanabilir placeholder
gostermez.

### Flutter Hesabim ekran haritasi

Mobil sunum katmani ortak contract gelmeden su ekranlari tasarlayabilir:

1. `Hesabim`: avatar/isim, e-posta ve dogrulama durumu, giris saglayicisi,
   profil duzenleme, guvenlik, oturumlar, engellenen hesaplar ve hesap silme
   girislerini tasir. Cikis aksiyonu bu ekranda kalir.
2. `Profil`: gorunen ad ve destekleniyorsa avatar duzenleme. E-posta profil
   formunun serbest metin alani degildir; guvenlik akisina gider.
3. `E-posta ve sifre`: Auth0 database hesabinda e-posta degisikligi ile sifre
   yenileme e-postasi; sosyal hesapta provider-yonetimli aciklama. Taze
   dogrulama sistem tarayicisinda yapilir, uygulama ici parola formu yazilmaz.
4. `Aktif oturumlar`: current cihaz belirgin, diger web/Android/iOS
   oturumlari listeli; tekil iptal ve `Diger tum oturumlari kapat` aksiyonu.
5. `Engellenen hesaplar`: bos durum, liste ve idempotent `Engeli kaldir`
   aksiyonu.
6. `Hesabi sil`: veri etkisini anlatan ozet, ikinci acik onay, taze Auth0
   dogrulamasi, isleniyor/tamamlandi/tekrar denenebilir hata durumlari.

Butun ekranlar loading, empty, error+retry ve success durumlarini; en az 44 px
dokunma hedefini, dynamic text/semantics ve native geri hareketini kapsar.
Contract PR'i gelene kadar UI testleri presentation-only fake repository ile
yazilabilir; fake JSON bir API sozlesmesi veya generated DTO kaynagi sayilmaz.
Production navigasyonunda capability cevabi olmayan calismayan bir aksiyon
gosterilmez.

Mobil yayin bayraklari birbirinden ayridir:

- `AUTH_ENABLED`, yalniz gercek Auth0 giris/cikis ve oturum tasimasini acar.
- `ACCOUNT_MANAGEMENT_ENABLED`, `/account/*` hesap yonetimi ekranlarini ve
  mutation rotalarini acar; varsayilani `false` olur ve ancak ortak contract,
  `HttpAccountRepository` ve fixture testleri tamamlaninca production'da
  `true` yapilir.

Bayrak kapaliyken hesap yonetimi girisleri gosterilmez ve deep-link/router
guard bu rotalara erisimi fail-closed reddeder. `FakeAccountRepository`
yalniz widget/router testlerinde veya acik gelistirme preview enjeksiyonunda
kullanilir; debug/release runtime'in varsayilan repository baglantisi olamaz.
Bu nedenle `AUTH_ENABLED=true`, sahte profil/e-posta/oturum/engel/silme
mutation'larini dolayli olarak acmaz.

`413a292` sunum teslimindeki
`beginSignIn() -> callback code -> deleteAccount(reauthCredential: code)`
zinciri yalniz FakeAccountRepository demosudur. Auth0 authorization code tek
basina production kaniti sayilmaz ve bu imza HTTP adapter'a tasinmaz. Ortak
contract geldiginde mobil, `/api/account/reauthentication/start` cevabiyla
sistem tarayicisini acar; callback'i PKCE verifier/state baglamiyla
`/api/account/reauthentication/complete` ucuna verir ve hesabi silme/e-posta
degisikligi mutation'inda yalniz sunucunun verdigi amaca bagli, kisa omurlu,
tek kullanimlik `reauthenticationToken`i kullanir. Bu akis mevcut
AuthRepository oturumunu tamamlamaz, yenilemez veya TokenStore'u degistirmez.

2026-07-30 itibariyla presentation-only ADR-047 ekranlari ve yayin korumasi
`codex/mobile@e596c6b` uzerindedir. `AUTH_ENABLED=true` iken gercek
giris/cikis kullanilabilir; varsayilan `ACCOUNT_MANAGEMENT_ENABLED=false`
yonetim girislerini gizler, alt rotalari `/account`a yonlendirir ve
`accountRepositoryProvider`a dokunmaz. `FakeAccountRepository` runtime
varsayilani degildir. Dal `main`e merge edilmemistir; ortak contract ve
`HttpAccountRepository` tamamlanana kadar bu durum korunur.

## Web → mobil entegrasyon kapıları

Mobil taraf aşağıdaki iki ortak teslimi `origin/main` uzerinden alip adapter/codegen entegrasyonuna devam eder:

| Teslim | Durum | Main'e giriş koşulu | Mobil tarafa bildirilecek çıktı |
| --- | --- | --- | --- |
| Responsive medya varyantları | MAIN'E MERGE EDILDI (PR #20, `ab1c92e`) | Public katalog, seri ve bölüm manifesti; istemcinin kullanabileceği varyant URL, piksel genişliği/yüksekliği ve MIME bilgisini `packages/contracts` şeması, OpenAPI eşlemesi ve sentetik fixture ile aynı biçimde döndürür. Storage key, Queue işi veya Studio metadata'sı public sözleşmeye sızmaz. Web contract/runtime testleri ve mobil kalite işi geçer. | `PublicMediaVariant` ile değişen `StoryPanelImage`/`SeriesMetadataFields` tanımları, response `schemaVersion: 1.0` (geriye uyumlu opsiyonel alanlar), OpenAPI `1.1.0` ve üç v1 fixture |
| Production auth/session | MAIN'E MERGE EDILDI (PR #21, `7ca0f24`) | ADR-039 Auth0'yu, sistem tarayıcılı Authorization Code + PKCE'yi, 15 dakikalık access tokenini ve 30 günlük dönen refresh tokenini seçer. Giriş/code exchange, refresh, revoke, kullanıcı özeti ve hata cevapları dil bağımsız şema/OpenAPI/fixture olarak tanımlanır. Web host-only cookie'si mobil sözleşme değildir. Gercek tenant/gateway/JWKS degerleri gelmeden fixture degerleri runtime config sayilmaz. | OpenAPI `1.2.0`, ADR-039, `AuthProviderConfigResponse`/token/state/error tanımları ve sentetik `auth-*.v1.json` fixture listesi |
| Production hesap yasam dongusu | CONTRACT VE WEB API RUNTIME MAIN'DE; WEB BFF PR/CI VE CANLI QA BEKLIYOR (ADR-047) | Profil, provider-yonetimli e-posta/sifre, web+native oturumlar, engellenen hesaplar ve Auth0 kimligini kapsayan silme iki platformun standart `Hesabim` kapsamidir. Web cookie ve mobil Bearer ayni `/api/account/*` yuzeyine girer; local PBKDF2 formlari kopyalanmaz. Ortak AccountActor, Management API adapteri, PKCE/JWE reauthentication, session/block ve silme saga'si `main`dedir. Web BFF state/nonce/PKCE callback, host-only cookie, exact logout ve acik eski-hesap baglama kaynak sinirinda tamamlandi; confidential web istemcisi ve canli QA bekler. | OpenAPI `1.4.1`; boş `AccountPasswordResetRequest` açık `properties: {}` nesnesidir. `AccountSessionPlatform.unspecified` sunucunun platformu çıkaramadığını, mobil codegen fallback'i `unknown` ise gelecekteki tanınmayan enum değerini anlatır. `AccountOverviewResponse` capability'leri, profil/e-posta/sifre aksiyonlari, birlesik session ve block DTO'lari, yapilandirilmis silme etkileri, `reauthentication/start|complete` PKCE istekleri ve tek kullanimlik kanit fixture'lari. Mobil `HttpAccountRepository` bu yuzeye baglanir; `ACCOUNT_MANAGEMENT_ENABLED` web BFF main + canli QA tamamlanmadan production'da acilmaz. |
| Editorial keşif akışı | MAIN'E MERGE EDILDI (bu teslim) | `GET /api/discovery`; öne çıkan seri ve ilk bölümü, ortak tür listesi, sunucunun 30 günlük kuralıyla belirlediği yeni seriler ve gerçek yayın sırasındaki en fazla 100 bölüm güncellemesini tek cevapta taşır. Yerelleştirilmiş tarih metninden sıralama yapılmaz; panel gövdeleri keşif payload'ına girmez. | OpenAPI `1.3.0`, `DiscoveryResponse`/`DiscoverySeriesSummary`/`DiscoveryEpisodeUpdate`, `discovery.v1.json` ve ADR-044 |
| Yeni bölüm push bildirimi | MAIN'E MERGE EDILDI (PR #35) | Herkese açık yeni bölüm duyurusu FCM topic fan-out kullanır. Web cihaz tokeni toplamaz, saklamaz veya mobil kayıt endpoint'i açmaz. Studio ilk yayın geçişinde tek topic mesajı dener; push hatası yayını ve e-posta outbox'ını geri almaz. | Flutter Firebase Messaging ile izin sonrası `panelya-new-episodes` konusuna `subscribeToTopic`, tercih kapanınca `unsubscribeFromTopic` uygular. Bildirim `data.deepLink` değerini mevcut custom-scheme router'a verir. |

Bir teslim yalnız pull request `main` dalına merge edildiğinde ve zorunlu CI kontrolleri geçtiğinde hazır sayılır. Web tarafı bu noktada mobil tarafa merge commit'ini ve yukarıdaki değişiklik özetini gönderir; mobil taraf `origin/main` aldıktan sonra codegen/adapter entegrasyonunu ayrı committe yapar.

## FCM topic sınırı

- Sabit konu adı `panelya-new-episodes` olur; bu değer API'den tahmin edilmez ve kullanıcı/seri kimliği taşımaz.
- Bildirim izni verilmeden topic aboneliği yapılmaz. Kullanıcı tercihi kapanınca `unsubscribeFromTopic` çağrılır.
- Mobil cihaz tokenini Panelya API'sine göndermez. Token yenileme, topic abonelik durumu ve yeniden deneme Firebase SDK sınırında kalır.
- Bildirim `data.deepLink` alanında `panelya://series/<seriesSlug>/read/<episodeSlug>` taşır. Mobil mevcut `resolveCustomSchemeRoute` sınırını kullanır; bilinmeyen veya bozuk hedef keşfe düşer.
- Foreground, background ve uygulama kapalı durumlarında açılış davranışı; Android 13+ izin akışı ve iOS APNs/FCM bağlantısı `QA-PUSH-01` ile fiziksel cihazda doğrulanır.

## Güncel web bilgi mimarisinin Flutter karşılığı

Mobil UI web bileşenlerini kopyalamaz, fakat içerik sırası ve kullanıcı niyeti aynı kalır:

1. `/` editorial keşif ekranıdır. Sıra: açılır tür dizini, haftanın hikâyesi, varsa cihaz-yerel `Okumaya devam et`, `Yeni Seriler`, `Yeni Eklenen Bölümler`. Yeni seri bölümü yeni bölüm bölümünden önce gelir.
2. Tür dizini varsayılan açık olabilir; kontrol yalnız `Türler` etiketi ve durum oku taşır. Kapalıyken aşağı, açıkken yukarı bakar; kontrol en az 44x44 ve semantics ile button/expanded durumunu açıklar. Bir tür seçmek `/catalog` ekranını o tür seçili halde açar.
3. Haftanın hikâyesi `featuredSeries` ve `featuredFirstEpisode` alanlarını kullanır. İlk bölüm yoksa okuma aksiyonu gösterilmez; seri inceleme aksiyonu çalışmaya devam eder.
4. Ana sayfa `newSeries` ve `latestEpisodes` dizilerinden en fazla dörder kart gösterir. `Tümünü Gör` aksiyonları sırasıyla `/new-series` ve `/new-episodes` rotalarına gider.
5. `/new-series` cevaptaki `newSeries` sırasını korur. Mobil istemci 30 günlük pencereyi veya `isNew` değerini cihaz saatinden yeniden hesaplamaz.
6. `/new-episodes` cevaptaki `latestEpisodes` sırasını korur. `publishedAt` yalnız ekranda gösterilecek yerelleştirilmiş etikettir; sıralama anahtarı değildir.
7. `/catalog` tam katalog, arama, tür/durum filtresi ve sıralama yüzeyidir. Mobil doğal lazy grid/list kullanır; web'e özgü 8/16/32 ve numaralı sayfa kontrollerini kopyalamaz. Arama Türkçe karakterleri normalize eder ve girilen ifadenin daha uzun katalog metninde geçmesini arar; kelimeleri bağımsız AND/OR koşullarına bölmez.
8. Yerel 100 serilik yük testi yalnız web API'sinin development seed'inden gelir. Flutter içine ikinci bir dummy katalog veya raster kapak kopyalanmaz; kapaksız kayıtlar mevcut tone gradyanına düşer.
9. Web reklam yerleşimleri mobil kapsamına otomatik taşınmaz. Mobil reklam/consent ayrı ürün ve mağaza kararı olmadan görünür placeholder üretmez.

Flutter tesliminin kabul kriterleri:

- `origin/main` alındıktan sonra `schema.json` codegen'i deterministik çalışır ve `discovery.v1.json` generated modellerle parse edilir.
- API client yalnız merkezi repository katmanında `/api/discovery` çağrısı ekler; ekran widget'ı ham HTTP veya JSON işlemez.
- `/`, `/catalog`, `/new-series` ve `/new-episodes` deep-link rotaları ile native geri hareketi test edilir.
- Loading, empty, error+retry ve success durumları tamamlanır; görünür ama çalışmayan CTA kalmaz.
- Telefon, tablet ve büyük yazı ölçeğinde overflow, en az 44x44 hedef, safe area, semantics ve azaltılmış hareket testleri geçer.

## Yerel cihaz testi

Simulator aynı Mac üzerinde çalışan web API'sine erişebilir. Fiziksel cihazda `localhost` Mac'i değil telefonu ifade eder; API origin'i Mac'in yerel ağ adresine veya güvenli bir geliştirme tüneline ayarlanmalıdır. Origin değeri kaynak koda gömülmez, mobil environment/config katmanından okunur.

## Paralel çalışma düzeni

- Mobil geliştirme yalnız `codex/mobile` branch'inde, `apps/mobile` altında ilerler; branch `origin/main` tabanlıdır.
- Web tarafındaki `codex/web` veya `codex/studio-media-workflow` branch'leri doğrudan merge edilmez; ortak değişiklikler `main` üzerinden alınır.
- Root web uygulaması `apps/web` altına taşınmaz; monorepo refactor'u ayrı planlanır.
- Her commit öncesi değişikliğin mobil kapsamla sınırlı olduğu kontrol edilir. Web/shared dosyada değişiklik gerektiği fark edilirse doğrudan değiştirilmez; hangi ortak sözleşmenin gerektiği raporlanır ve `main` üzerinden koordine edilir.

## Ortaklık kuralları

1. Web bileşenleri kopyalanmaz; platforma özgü Flutter widget'ları yazılır ama ortak tasarım token'ları kullanılır.
2. Seri, bölüm, panel, medya, okuma ilerlemesi, pagination ve API hata modellerinin bağımsız mobil kopyaları türetilmez; Dart modelleri API JSON sözleşmesini birebir izler.
3. Ortak sözleşmenin tek kaynağı `packages/contracts/schema.json` (JSON Schema 2020-12), HTTP eşlemesi `packages/contracts/openapi.json` dosyasıdır. Web ve mobil parser/model testleri `packages/contracts/fixtures` içindeki aynı sentetik cevapları kullanır. Kaynak `main`'e gelene kadar mobildeki `apps/mobile/lib/core/contracts/` adapter katmanı geçici kalır; entegrasyondan sonra Dart modelleri bu sözleşmeyle doğrulanır veya üretilir.
4. Tasarım değerleri ileride `packages/design-tokens` tek kaynağına bağlanacak; o zamana kadar mobil tema `app/globals.css` token'larını birebir aynalar (aşağıdaki tablo).
5. API çağrıları ekran widget'larına dağıtılmaz; `apps/mobile/lib/core/api/` altındaki merkezi client katmanından geçer.
6. API origin'i kaynak koda gömülmez; `env/` dart-define config katmanından okunur.

## Tasarım token'ları (kaynak: `app/globals.css`)

| Token | Değer | Kullanım |
| --- | --- | --- |
| background | `#07100e` | Ana arka plan (koyu orman yeşili) |
| surface | `#0b1512` | Ana yüzey |
| surface2 | `#101d19` | İkinci yüzey |
| surface3 | `#162520` | Üçüncü yüzey |
| ink | `#f3f6f2` | Ana metin |
| muted | `#94a39d` | Soluk metin |
| line | `rgba(197,226,213,.14)` | Çizgi/kenarlık |
| mint | `#66e2ae` | Ana vurgu |
| mintStrong | `#35c98e` | Güçlü vurgu |
| coral | `#ff6f61` | Uyarı/ikincil vurgu |

Yeni veya bağımsız renk paleti oluşturulmaz. Mobil birebir web kopyası olmaz; ancak tipografi hiyerarşisi, içerik sırası, kart dili, renkler ve durum mesajları aynı ürün ailesinden görünür.

## Kalite çizgisi

- Dokunma hedefleri en az 44x44.
- Safe area, native geri hareketi ve erişilebilirlik (semantics, dinamik yazı boyutu, azaltılmış hareket) desteklenir.
- Her ekran loading, empty, error (retry ile) ve success durumlarını tamamlar.
- Görünür olup çalışmayan buton veya placeholder bırakılmaz (ADR-010 mobilde de geçerli).

## Şimdilik sonraya bırakılanlar

ADR-047 mobil runtime entegrasyonu devam eder; production aktivasyonu web
runtime PR'i, Auth0 Management M2M/web BFF provision'i ve canli iki-provider
QA turunu bekler. Cevrimdisi indirme, abonelik/odeme ve Studio/admin ekranlari
ilk mobil kapsamin disindadir.

## Ortak değişiklik sınırı

Aşağıdakiler `main` üzerinden koordine edilir:

- API alan adı veya JSON şekli değişiklikleri
- auth/session sözleşmesi
- seri, bölüm, panel ve okuma ilerlemesi tipleri
- medya URL ve cache davranışı
- D1 migration'ları

Yalnız mobil navigasyon, native UI, cihaz depolaması ve Flutter yapılandırması `codex/mobile` içinde bağımsız ilerleyebilir.
