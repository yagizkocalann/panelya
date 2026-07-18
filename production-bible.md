# Panelya Production Bible

## 1. Urun tezi

Panelya, Turkce ve mobil-oncelikli bir dikey cizgi hikaye okuma platformudur. Ilk teslimat web uygulamasidir; mobil uygulama, web urun akisi ve veri sozlesmeleri oturduktan sonra Flutter ile ayni API'yi ve dil bagimsiz JSON sozlesmelerini kullanir (ADR-019).

Referans alinan urun ilkeleri:

- Ana sayfa kesif ve geri donus icin; seri sayfasi karar ve ilerleme icin; okuyucu kesintisiz tuketim icindir.
- Okuyucu icerigi 690-800 px merkez kolonda, bosluksuz dikey akista sunulur.
- Ilk kareler oncelikli, devam kareleri tembel yuklenir; bolum gecisleri hem ustte hem altta erisilebilirdir.
- Referans sitenin marka, metin, gorsel, logo ve telifli serileri kopyalanmaz. Yalnizca urun kaliplari incelenir.

## 2. MVP kapsami

P0 web:

1. Kesif ana sayfasi: one cikan seri, yeni bolumler, yeni seriler, tur filtreleri ve arama.
2. Seri sayfasi: kapak, ozet, turler, durum, bolum listesi ve okumaya basla/devam et.
3. Okuyucu: dikey paneller, ilerleme gostergesi, onceki/sonraki bolum ve seri sayfasina donus.
4. Backend siniri: `/api/catalog` JSON sozlesmesi. Katalog ve yayin durumu D1'den okunur; typed seed eksik bundled original kayitlarini idempotent ekler ve public okuma geri dususu saglar.
5. Responsive ve klavye erisilebilirligi; PC monitor, tablet ve mobil ekran destegi; azaltmis hareket tercihi.

P1 (yerel dikey dilim basladi):

- Tamamlanan: yerel hesap, oturum, profil/sifre/hesap silme, kutuphane, favori, okuma durumu, hesaplar arasi okuma ilerlemesi, rol korumali Studio kabugu, kurumsal/yasal bilgi sayfalari ve lokal iletisim mesaj kutusu.
- Tamamlanan: yerel e-posta dogrulama, sifre sifirlama, oturum iptali, D1 outbox bildirim adaptoru ve hassas auth uclarinda sabit pencereli yerel rate limit.
- Tamamlanan: seri bazli puan/yorum, spoiler gizleme, okuyucu raporlama ve Studio moderasyon kuyrugu.
- Tamamlanan: Studio'da seri ve bolum CRUD, taslak/yayin/arsiv durumlari, one cikarma ve D1 tabanli public katalog yayini.
- Tamamlanan: Studio R2 kapak/panel yukleme, JPEG/PNG/WebP dosya-imza-boyut-piksel dogrulamasi, D1 medya metadata'si ve yayin durumuna bagli public medya servisi.
- Siradaki: panel siralama/kaldirma, taslak onizleme ve production olcekli dagitik rate limit.
- D1 tablolarina gecis hesap ve katalog verisi icin tamamlandi. Medya yerelde R2 binding emulasyonu kullanir; production bucket yasam dongusu ve turetilmis format kuyrugu deployment oncesi tamamlanir.
- Arama indeksi, moderasyon, telif bildirim sureci, analitik ve hata izleme.

P2:

- Flutter mobil uygulamasi (ADR-019), deep link, cevrimdisi son bolum, bildirimler.
- Ucretli bolum/abonelik ancak lisans ve odeme modeli kesinlestikten sonra.

## 3. Teknik kararlar

- Dil: Web'de TypeScript, mobilde Dart/Flutter. Veri modeli paylasimi kod degil dil bagimsiz sozlesme kaynagi (JSON Schema/OpenAPI) uzerinden saglanir; web TypeScript tiplerini, mobil Dart modellerini bu kaynaktan uretir.
- Web: Next.js App Router + React Server Components; mevcut vinext/Cloudflare Workers yapisi korunur.
- API: Web ile ayni deployment icinde Route Handlers. Mobil asamasinda ayni JSON sozlesmeleri kullanilir.
- Veri: Cloudflare D1 + Drizzle. Typed seed bos veritabanini baslatir ve public okumalarda gecici D1 arizasina karsi guvenli geri dusus saglar. Temel varliklar: User, Series, Genre, SeriesGenre, Episode, EpisodeAsset, ReadingProgress, LibraryItem, Review.
- Medya: kaynak kapak/paneller hashli ve degismez anahtarla R2'ye yazilir; metadata D1'de tutulur. Public nesne yalniz yayindaki seri/bolumun halen bagli asset'i ise servis edilir. Turetilmis responsive formatlar Cloudflare Images/edge cache sonraki dilimdir.
- Kimlik: Yerel gelistirmede PBKDF2 tabanli parola, HttpOnly SameSite oturum ve origin kontrolu kullanilir. Ilk yerel hesap kolaylik amaciyla admin olur. Bu otomatik yetki ve uygulama-ici kimlik modeli production icin onaylanmis degildir; production oncesi yonetilen kimlik saglayicisi ve rate limit karari zorunludur.
- Mobil: Flutter istemcisi ayri `apps/mobile` dizininde yasar (ADR-019). Web ile kod degil API sozlesmesi paylasilir; Dart modelleri `schemaVersion`'li JSON sozlesmesinden turetilir.
- SEO: seri ve bolum bazli metadata, canonical, sitemap ve yapılandirilmis veri P1'in erken parcasi.

## 4. Veri modeli cekirdegi

```text
Series 1---N Episode 1---N EpisodeAsset
Series N---N Genre
User 1---N ReadingProgress N---1 Episode
User 1---N LibraryItem N---1 Series
User 1---N Review N---1 Series
```

Episode sirasinda gorunen etiket ile dahili `sequence` ayridir; prolog/0/ara bolumleri destekler. Her EpisodeAsset `position`, `width`, `height`, `mimeType`, `storageKey` ve `blurData` tasir.

## 5. API sozlesmesi

- `GET /api/catalog`: ozet seri kartlari ve one cikan seri.
- `GET /api/series/:slug`: seri, turler ve bolumler.
- `GET /api/series/:slug/episodes/:episodeSlug`: okuyucu manifesti.
- `POST /api/auth/*`: yerel kayit, giris, cikis, e-posta dogrulama ve sifre sifirlama.
- `POST /api/account/*`: profil, sifre ve hesap silme.
- `POST /api/account/sessions/*`: kullanicinin diger oturumlarini tekil veya toplu kapatma.
- `GET/POST /api/library/*`, `POST /api/progress`: yetkili okuyucu durumu.
- `POST /api/contact`: lokal iletisim, uretici ve telif mesaji kaydi.
- `POST /api/admin/messages/:id`: admin mesaj durumu guncelleme.
- `POST /api/reviews/:slug`: kullanicinin seri degerlendirmesini ekleme, guncelleme veya silme.
- `POST /api/review-reports/:id`: yayindaki bir yorumu neden ve istege bagli aciklamayla raporlama.
- `POST /api/admin/moderation/*`: yorumu gizleme/yayinlama ve raporu cozme/reddetme.
- `POST /api/admin/content/series`, `POST /api/admin/content/episodes`: Studio hostuna, admin rolune ve ayni-origin kontrolune bagli icerik mutation'lari.
- `POST /api/admin/media`: Studio hostunda admin dosya dogrulamasi, R2 yazimi ve icerik baglantisi.
- `GET /api/admin/media/:id`: host-only Studio oturumuna bagli private onizleme.
- `GET /api/media/:id`: yalniz yayindaki ve halen bagli medya varligi; immutable public cache.
- Studio UI ayri bir hostta (`studio.<ana-domain>`, yerelde `studio.localhost`) ve admin rol korumali calisir. Yonetici mutation'lari Studio hostundaki `/api/admin/*` altinda ayrilir.

Liste endpoint'leri cursor tabanli sayfalama kullanir. API cevaplari surumlenebilir bir `schemaVersion` alani tasir.

Public katalog, seri detay ve bolum manifesti icin dil bagimsiz tek kaynak `packages/contracts/schema.json`; HTTP path/response eslemesi `packages/contracts/openapi.json` altindadir. Sentetik fixture'lar ve derlenmis Worker cevaplari ayni JSON Schema'ya karsi test edilir. Breaking alan/tip degisikligi yeni `schemaVersion` ve koordineli web/Flutter gecisi gerektirir.

## 6. Kalite kapilari

- `npm test`, `npm run lint`, `npm run build` basarili.
- 360/390 mobil, 768 tablet dikey, 1024 tablet yatay ve 1280/1440 PC monitor gorunumlerinde yatay tasma yok; okuyucu metni ve kontroller klavye ile erisilebilir.
- Mobil ve tablet dokunma hedefleri en az 44 x 44 px; ana, seri ve okuyucu route'lari her cihaz sinifinda ayri dogrulanir.
- Katalog, seri ve okuyucu route'lari 200; bilinmeyen seri/bolum 404.
- Console error yok; ilk viewport'ta gereksiz buyuk istemci paketi yok.
- Telifli icerik veya referans site asset'i repoya girmez.

## 7. Gorsel dil

- Marka: Panelya. Referanstan bagimsiz, gece laciverti zemin; mercan ve mint vurgular.
- Tipografi: basliklarda yuvarlak ve guclu, govdede yuksek okunabilirlik.
- Kartlar keskin bilgi hiyerarsisine, posterler 3:4 orana sahiptir.
- Okuyucu yuzeyi neredeyse siyah; chrome minimum; hikaye panelleri merkezde.
- Okuyucu SEO'su `noindex,follow`; seri ve katalog sayfalari indexlenebilir. Ilk 1-3 panel/gorsel oncelikli, kalanlar lazy yuklenir ve tum asset'lerde genislik/yukseklik bulunur.

## 8. GPT Image pilot kurallari

- Yalnizca tamamen ozgun karakter, evren ve senaryo.
- Uretim sirasi: premise -> beat sheet -> karakter/model sheet -> stil master -> panel plan -> kare uretimi -> tutarlilik QA -> WebP export.
- Stil master onaylanmadan seri panel uretimi yapilmaz.
- Her gorsel icin prompt, seed/istek kimligi, boyut, versiyon ve hak/provenance notu tutulur.
- Dakikada en fazla 8 istek; mekanik kuyruk ve kare sayimi uretici modelden ayrilir.
- Ilk stil-master pilotu `public/images/gece-vardiyasi-style-master.webp`; provenance ve prompt `artifacts/gece-vardiyasi/style-master.md` icinde.
- Romantik webtoon arastirma seti `artifacts/style-research/` icinde. `korean-romance-webtoon-production-rulebook.md` gorsel, anlatim, speech, uretim ve QA icin gecerli standardi tanimlar. `master-refined.png` fazla painterly/sinematik ve tek modlu kaldigi icin master olarak reddedildi; `/bir-bilet-uzaginda/bolum-1` rotasinda yalniz eski karsilastirma pilotu olarak kalir. Yeni uretim, 12 karelik N/C/B/E master testinden en az 85 almadan baslamaz.
- Yeni ozgun romantik gizem pilotu `artifacts/yarinki-ses/` altindadir. Hikaye, karakter kilitleri, 18 panellik beat/lettering plani ve prompt-provenance kayitlari gorsel uretimden once tamamlandi; 18/18 kabul paneli QA'dan 93/100 aldi. Paneller sessizdir, Turkce metin ayri HTML katmaninda okunur ve `/yarinki-ses/bolum-1` rotasinda yayinlanir.
- `Dorduncu Anahtar` 12 karelik arka plan deneyi, kabul edilmis karakter sheet'lerini degistirmeden foto-gercekci arka plan sorununu E/N/B/C register sistemiyle sinadi ve teknik/gorsel QA'dan 92/100 aldi. Deneyde dogrulanan cizgisel/mat arka plan grameri ile kullanicinin T1/T2/T3 yogunluk sistemi `webtoon-kural-kitabi-v2.md` birlesik adayinda toplandi; kullanici style-master ve kural kitabi onayi gelmeden seri uretime veya kataloga alinmaz.

## 9. Guvenlik ve hukuk

- Yuklenen dosyalarda MIME, boyut, piksel, malware ve sahiplik kontrolu.
- UGC icin raporlama, moderasyon ve tekrar ihlal politikasi.
- KVKK/GDPR veri envanteri, hesap silme ve saklama sureleri P1 cikis kosuludur.
- Yayin hakki dogrulanmayan mevcut webtoon bolumleri barindirilmaz.

## 10. Degisiklik disiplini

Her ajan once bu dosyayi ve `AGENTS.md` dosyasini okur. Yeni mimari kararlar once buraya kisa ADR maddesi olarak eklenir. P0 disi bir ozellik, P0 kalite kapilarini geciktiriyorsa ertelenir.

## 11. Kabul edilmis ADR ozeti

- ADR-001 / Moduler monolit: P0'da web, route handler ve domain verisi ayni deploy'da; is kurallari sayfa JSX'ine dagitilmaz.
- ADR-002 / Depolama: P0 typed seed. Sites/Cloudflare yolu icin ilk kalici aday D1 + Drizzle, medya icin R2. Auth, odeme veya karmasik raporlama P1 kapsaminda kesinlesmeden once PostgreSQL alternatifi yeniden degerlendirilir.
- ADR-003 / Medya manifesti: Bir bolum tek mega gorsel degil, sirali asset listesidir. Yayinlanan URL'ler hashli ve immutable olur.
- ADR-004 / Mobil: Web UI kodu mobile tasinmaz; her platform kendi native UI'sini yazar. Paylasim, dil bagimsiz sozlesmeler (JSON Schema/OpenAPI kaynakli contracts) ve design token degerleri uzerinden olur. Stack karari icin bkz. ADR-019.
- ADR-005 / Lisans: Seed/demo katalog yalniz ozgun, komisyonlu veya acikca lisansli icerikten olusur.
- ADR-006 / Studio hostu: Yonetim paneli public siteden ayri hostta calisir. Production hedefi `studio.<ana-domain>`, yerel hedef `studio.localhost` olur. Ilk fazda ayni deployment ve D1 paylasilir; host tabanli yonlendirme public `/studio` isteklerini Studio hostuna tasir. Studio oturumu host-only cookie kullanir ve public oturum otomatik paylasilmaz.
- ADR-007 / Yerel kimlik: Ilk kayit admin, sonraki kayitlar reader olur. Yalniz yerel QA kolayligidir; production'a aynen tasinmaz.
- ADR-008 / Reklam testi: Local ve gelistirme ortaminda Google Publisher Tag'in resmi ornek test agi ve `/6355419/Travel/Europe/France/Paris` birimi kullanilir. Panelya publisher kimligi, gercek kampanya, gelir, sahte reklam veya otomatik tiklama yoktur. Test durumu Studio hostundaki `/ads` ekranindan izlenir.
- ADR-009 / Studio bilgi mimarisi: Studio dis URL'leri `/`, `/content`, `/messages`, `/ads`, `/outbox` ve `/moderation` olarak ayrilir; kaynak route'lari kod siniri icin `app/studio` altinda kalir. Ana moduller Dashboard, Icerik, Medya, Yayin, Moderasyon, Kullanicilar/Roller, Reklam, Analitik ve Audit/Ayarlar olur; mutation API'leri `/api/admin/*` altinda kalir.
- ADR-010 / Etkilesim butunlugu: Tiklanabilir gorunen her UI ogesi calisan bir route, form mutation'i veya istemci etkilesimine sahip olur. Henuz uygulanmayan aksiyon disabled buton olarak gosterilmez; bilgi metni olarak kalir. Auth ekranlari geri ve kapat kontrolleri sunar.
- ADR-011 / Bildirim saglayici siniri: Yerel gelistirmede dogrulama, sifirlama ve guvenlik bildirimleri D1 `notification_outbox` tablosuna yazilir ve yalnizca admin Studio ekranindan acilir. Route ve is kurallari saglayici SDK'sina bagimli degildir; production e-posta saglayicisi ayni `NotificationDelivery` sozlesmesini uygular.
- ADR-012 / Hesap tokenlari ve oturumlar: Dogrulama/sifirlama tokenlari 256 bit CSPRNG ile uretilir, `account_tokens` icinde yalniz SHA-256 hash olarak, tek kullanimlik ve sureli tutulur. Sifre sifirlama butun oturumlari; e-posta degisikligi diger oturumlari kapatir. Hassas auth cevaplari hesap varligini aciklamaz.
- ADR-013 / Topluluk moderasyonu: Her dogrulanmis hesap seri basina tek degerlendirme tutar; puan zorunlu, yorum istege baglidir. Raporlar ayri kuyrukta tutulur, rapor sayisi yorumu otomatik gizlemez. Yalniz admin aksiyonu yayini degistirir ve tum islemler audit kaydi uretir.
- ADR-014 / Romantik webtoon stil pilotu: Referans eserlerden yalniz genel dikey ritim, kadraj ve arka plan yogunlugu ilkeleri incelenir. Uretim tamamen ozgun karakter/sahneyle yapilir. Master adayi temiz ince kontur, iki kademeli cel golge ve yalniz atmosferde secici suluboya kullanir; metin ve balonlar ayri katmandir. Yerel demo, katalog ve okuyucu butunlugunu test etmek icin tek uzun gorsel varlik kullanabilir; production bolumleri ADR-003 uyarinca sirali panel asset'lerine ayrilir.
- ADR-015 / D1 icerik kaynagi: Studio seri ve bolum kayitlari D1'de acik alanlar ve yayin durumuyla tutulur. Public katalog yalniz `published` seri ile en az bir `published` bolumu dondurur; taslak ve arsiv kayitlari sizmaz. Typed katalog eksik bundled original kayitlarini `INSERT OR IGNORE` ile idempotent ekler; mevcut Studio degisikliklerini ezmez ve build probe/gecici D1 arizasinda public okuma geri dususu olarak kalir. Mutation'lar yalniz Studio hostundaki admin API'lerinden yapilir ve audit kaydi uretir.
- ADR-016 / Romantik webtoon uretim grameri: Belirli sanatci veya eser kopyalanmaz; temiz modern dijital romantik webtoonun genel cizgi ekonomisi, mobil ritmi ve oyunculuk ilkeleri kullanilir. Bolum tek uzun AI gorseli olarak uretilmez. Paneller N normal, C komedi, B duygusal vurgu ve E kurucu modlariyla ayri uretilir; metin/SFX ayri katmanda dizilir. Yeni stil, 12 karelik master paketi ve 100 uzerinden en az 85 QA puani olmadan seri uretimine giremez.
- ADR-017 / R2 medya siniri: Binary medya D1'e yazilmaz; R2 binding arkasindaki `MediaStorage` adaptoru kullanilir. D1 yalniz hashli storage key, MIME, byte, piksel, sahiplik ve icerik baglantisini tutar. Upload dosya imzasi ile beyan edilen MIME'i birlikte dogrular ve hata halinde R2/D1 telafisi yapar. Public endpoint, asset'in yayindaki icerikte halen bagli oldugunu her istekte kontrol eder.
- ADR-018 / Repository ve paralel istemci akisi: `main` web ve mobil icin dogrulanmis ortak tabandir. Windows web gelistirmesi `codex/web`, MacBook mobil gelistirmesi `codex/mobile` branch'inde ilerler; API, auth, migration ve domain sozlesmesi degisiklikleri `main` uzerinden koordine edilir. Agir imagegen/arastirma rasterlari Git'e alinmaz; metin provenance/QA dosyalari kalir ve web runtime asset'leri optimize WebP olarak commit edilir.
- ADR-019 / Mobil istemci stack'i (ADR-004 revizyonu): Mobil uygulama Expo/React Native yerine Flutter ile yazilir; iskelet olarak mevcut Novel-Project uygulamasinin kanitlanmis kaliplari (feature-first yapi, Riverpod state, go_router, design token temasi, env/dart-define katmani, repository interface deseni) baz alinir. TypeScript tip paylasimi hedefi dusurulur; ortak sozlesme kaynagi dil bagimsiz JSON Schema/OpenAPI olarak tutulur, web TypeScript tiplerini ve mobil Dart modellerini bu kaynaktan uretir. Sozlesme kaynagi `main`'e gelene kadar Dart modelleri `schemaVersion` tasiyan mevcut JSON API cevaplarini birebir aynalar ve sozlesme degisiklikleri `main` uzerinden koordine edilir. Mobil istemci D1/R2'ye dogrudan baglanmaz, yalniz web deployment'inin API sinirini kullanir. Novel'in Firebase katmani tasinmaz; ayni repository interface'lerinin arkasina Panelya REST client'i yazilir. Okuyucu, video pager degil kesintisiz dikey panel scroll'u olarak sifirdan uygulanir.
- ADR-020 / Ortak API sozlesmesi: Public katalog, seri detay ve bolum manifesti sekilleri JSON Schema 2020-12 ile `packages/contracts/schema.json` icinde tanimlanir; OpenAPI 3.1 dosyasi endpoint'leri bu semalara baglar. Web runtime cevaplari ve dil bagimsiz fixture'lar CI'da ayni semaya karsi dogrulanir. Mevcut zorunlu alanin kaldirilmasi veya tipinin degismesi breaking sayilir ve yeni `schemaVersion` gerektirir.
