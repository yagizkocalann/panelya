# Panelya manuel QA ve kullanici test kuyrugu

Bu dosya, otomatik testlerden gecmis olsa bile urun sahibi tarafindan sonradan elle denenmesi gereken gorunur akislarin kalici kaydidir. Yeni veya degisen her feature buraya eklenir. Parola, token, gercek e-posta, API anahtari veya baska hassas veri yazilmaz.

Durumlar:

- `BEKLIYOR`: Kullanici testi henuz yapilmadi veya yeni surumden sonra tekrar gerekli.
- `GECTI`: Kullanici akisi elle dogruladi; tarih ve kisa not eklenir.
- `BLOKE`: Testi engelleyen servis, veri veya ortam eksigi var.

## Oncelikli hatirlatma kuyrugu

| ID | Durum | Feature | Nerede | Elle test edilecek ana sonuc |
| --- | --- | --- | --- | --- |
| QA-ADM-01 | BEKLIYOR | Yonetici davetini kabul etme | `http://studio.localhost:3000/users` -> `/outbox` | Yeni, hesabi olmayan test adresine davet olustur; outbox'tan ac; parola belirle; Studio'ya yeni admin olarak girildigini ve davetin `Kabul edildi` oldugunu dogrula. |
| QA-ADM-02 | BEKLIYOR | Davet yenileme ve iptal | `http://studio.localhost:3000/users` | Yenilenen eski baglantinin calismadigini; iptal edilen davetin kabul edilemedigini dogrula. |
| QA-AUTH-01 | BEKLIYOR | Kayit, giris, cikis | Public `/register`, `/login`, `/account` | Mobil ve PC'de geri/kapat kontrolleri, hata mesajlari ve oturum gecisleri calismali. |
| QA-AUTH-02 | BEKLIYOR | E-posta dogrulama ve sifre sifirlama | Public auth ekranlari + Studio `/outbox` | Tek kullanim, suresi dolmus baglanti ve sifre sonrasi eski oturumlarin kapanmasi dogrulanmali. |
| QA-CONT-01 | BEKLIYOR | Seri ve bolum yayin akisi | Studio `/content` | Taslak seri/bolum publicte gorunmemeli; yayinlandiginda katalog, seri ve okuyucuya gelmeli; arsivde tekrar kalkmali. |
| QA-MED-01 | BEKLIYOR | Kapak/panel yukleme ve responsive turetme | Studio `/media` ve bolum editoru | Gecersiz dosya reddedilmeli; gecerli gorsel yuklenmeli; 480/768/1200 kuyrugu tamamlanmali ve okuyucu uygun `srcset` varligini kullanmali. |
| QA-MED-02 | BEKLIYOR | Production responsive kuyruk teslimi | Studio `/media` + Cloudflare Queue test ortami | `cloudflare_queue` modunda is teslim edilmeli ve worker varyanti tamamlamali; eksik binding'de basarili gorunmemeli; yeniden gonderme ayni varyanti cogaltmamalidir. |
| QA-PREV-01 | BEKLIYOR | Guvenli taslak onizleme | Studio seri/bolum editoru | Link taslagi gostermeli; kapsam disi medya acilmamali; iptal ve 30 dakika bitisinden sonra link calismamali. |
| QA-COMM-01 | BEKLIYOR | Puan, yorum, spoiler ve raporlama | Public seri sayfasi + Studio `/moderation` | Yorum ekle/guncelle/sil, spoiler gizleme, rapor, gizleme/yayinlama ve rapor cozum akislarini iki farkli test hesapla dene. |
| QA-COMM-02 | BEKLIYOR | Yorum yaniti, begeni ve kullanici engelleme | Public seri sayfasi + `/account` + Studio `/moderation`; on kosul: e-postasi dogrulanmis iki test hesabi | A hesabi B'nin yorumunu begenip geri alabilmeli ve tek seviyeli yanit yazip silebilmeli. B engellenince iki hesap birbirinin yorum/yanitlarini gormemeli ve etkilesim reddedilmeli; `/account`tan engel kaldirilinca icerik geri gelmeli. Admin yaniti gizleyip yeniden yayinlayabilmeli. 1440/1024/768/390/360 px'te aksiyonlar ulasilabilir ve en az 44 px olmali. |
| QA-COPY-01 | BEKLIYOR | Telif bildirimi ve gizli durum takibi | Public `/copyright` -> `/copyright/report`; Studio `/messages`; on kosul: yerel admin hesabi | Tek bir Panelya URL'siyle bildirim gonder; gizli durum linkini kaydet; Studio'da `Inceleniyor`, `Ek bilgi bekleniyor`, `Islem tamamlandi` ve `Uygun bulunmadi` durumlarini public yanitla guncelle. Link yalniz referans/durum/yanit gostermeli, Studio'daki e-posta ve hak aciklamasini sizdirmamali; gecersiz link 404 ve no-store/no-referrer/noindex olmali. 1440/1024/768/390/360 px'te form, durum ve Studio kartlari tasma yapmamali, kontroller en az 44 px olmali. |
| QA-FOL-01 | BEKLIYOR | Kutuphane, favori, takip ve yeni bolum bildirimi | Public seri sayfasi + `/library`; Studio `/content` + `/outbox` | Iki test hesapla kutuphane/favori aktif durumlarini, takipten bagimsizligini ve bildirim tercihini dogrula. Yayindaki seriye ilk kez yeni bolum yayinlandiginda yalniz tercihi acik ve dogrulanmis takipci icin tek `Yeni bolum` outbox kaydi olusmali; yeniden kaydetme kopya uretmemeli. |
| QA-CAT-01 | BEKLIYOR | Katalog arama, filtre, siralama ve cursor | `http://localhost:3000/?view=catalog`; on kosul: en az 8 yayinlanmis seri | Turkce karakterli baslik/uretici aramasi, tur ve devam/tamamlandi filtreleri, uc siralama ve `Sonraki sonuclar` baglantisi dogru kalmali; sayfalar arasi seri tekrari olmamali, bozuk cursor ilk sayfaya guvenli dusmeli. 1440/1024/768/390/360 px'te form ve pagination ulasilabilir olmali. |
| QA-ROLE-01 | BEKLIYOR | Kullanici rol yonetimi | Studio `/users` | Kendi rolunu degistirememe, son admin korumasi ve rol degisince hedef oturumlarin kapanmasi dogrulanmali. |
| QA-SEC-01 | BEKLIYOR | Atomik ve dagitik rate-limit | Studio `/qa`; public `/login`, `/register`, `/forgot-password`; Studio yonetici mutation'lari | Yerelde `d1_strict` etiketi gorunmeli ve kota tam sinirda reddetmeli. Production testinde `cloudflare_hybrid` etiketi gorunmeli; eksik binding fail-closed olmali ve hesap varligi sizmamali. |
| QA-SEC-02 | BEKLIYOR | Idle timeout, host kapsami ve yeniden dogrulama | Public `/account/sessions`; Studio `/users`, `/outbox`, `/messages`, seri/bolum editoru; on kosul: yerel admin hesabi | Public ve Studio girisleri ayri oturumlar olarak gorunmeli. Studio session satirinin `last_seen_at`/`idle_expires_at` degerini yerel D1'de 30 dakikadan eski yapinca Studio yeniden giris istemeli; public oturum etkilenmemeli. `authenticated_at` degerini 10 dakikadan eski yapinca hassas butonlar parola dogrulama baglantisina donmeli; yanlis parola reddedilmeli, dogru parola sonrasi token hash degismeli ve rol/davet/outbox/telif/onizleme islemi yeniden denenebilmelidir. 1440/1024/768/390/360 px'te geri/kapat ve form kontrolleri ulasilabilir, en az 44 px olmali. Ham parola veya session token audit/loglarda gorunmemeli. |
| QA-OPS-01 | BEKLIYOR | Production platform hazirligi | Studio `/qa` + `/api/admin/platform-readiness` + Cloudflare deployment kaynagi | Production profili otomatik D1/R2/Images/Queue/rate-limit kontrollerini gecmeli; consumer retry ve DLQ ayari ayrica gorulmeli; eksik binding 503 vermeli. |
| QA-OPS-02 | BEKLIYOR | D1/R2 yedek ve geri yukleme tatbikati | `docs/backup-restore-runbook.md` + izole D1/R2 test kaynaklari | Kurtarma paketi verifier'dan gecmeli; yeni D1 ve ayri R2 test kovasina geri donmeli; katalog/medya smoke gecmeli; eski oturum, token, preview ve davetler kullanilamamali. |
| QA-SEO-01 | BEKLIYOR | Public SEO ve tarama siniri | On kosul: test/production `PUBLIC_SITE_ORIGIN` gercek public domaine ayarli. Public `/robots.txt`, `/sitemap.xml`, `/`, bir seri ve bir okuyucu URL'si; Studio `/robots.txt` | Canonical URL'ler public domaine gitmeli; sitemap yalniz indexlenebilir kurumsal/seri rotalarini icermeli; okuyucu `noindex,follow`, Studio robots ise tum taramayi kapatmali; seri JSON-LD yayin verisiyle uyusmali. |
| QA-ADS-01 | BEKLIYOR | Google resmi test reklami | Public reklam alanlari + Studio `/ads` | Yalniz resmi Google test birimi gorunmeli; gercek publisher veya tiklama otomasyonu olmamali. |
| QA-STU-06 | BEKLIYOR | Outbox saklama ve temizleme | Studio `/outbox` | Saklama sayilari dogru olmali; buton yalniz suresi dolan kayit varsa gorunmeli; temizlik aktif kaydi silmemeli ve audit olayi olusturmali. |
| QA-RESP-01 | BEKLIYOR | Responsive genel tur | Public ana/seri/okuyucu, auth ve Studio; on kosul: public okuyucu ve ayri Studio admin oturumu | 1440, 1024, 768, 390 ve 360 px'te yatay tasma, kirpik kontrol, 44 px alti dokunma hedefi veya ulasilamayan aksiyon olmamali. 2026-07-19 otomatik/ajan turunda 41 public URL sablonu, authenticated public hesap/kutuphane, Studio girisi, linkler ve console temizdi; tablet ust menusu 44 px'e duzeltildi. Yetkili Studio ekranlarinin bes viewport turu kullanici testinde tamamlanacak. |

## Tam feature matrisi

### Public okuma

- [ ] `QA-PUB-01` Ana sayfa arama ve tur filtresi dogru kartlari getiriyor.
- [ ] `QA-PUB-02` Seri sayfasi basla/devam et, bolum listesi ve topluluk alanini bagliyor.
- [ ] `QA-PUB-03` Okuyucu onceki/sonraki, ilerleme, tema ve dikey panel akisinda calisiyor.
- [ ] `QA-PUB-04` Bilinmeyen seri/bolum 404; hakkimizda, iletisim ve yasal footer linkleri calisiyor.
- [ ] `QA-PUB-05` Kutuphane, favori ve hesaplar arasi okuma ilerlemesi korunuyor.
- [ ] `QA-PUB-06` Public canonical, robots, sitemap ve ComicSeries JSON-LD ayni production origin'ini kullaniyor; taslak, Studio, API, hesap ve okuyucu URL'leri sitemap'e sizmiyor.
- [ ] `QA-PUB-07` Seri sayfasinda kutuphane/favori/takip aktif durumu hesaba gore server-render ediliyor; yeni bolum tercihi `/library` uzerinden de yonetiliyor ve ilk yayin bildirimi idempotent kaliyor.
- [ ] `QA-PUB-08` Katalog kesfinde normalize arama, tur/durum filtresi, guncelleme/puan/ad siralamasi ve cursor sayfalama ayni D1 yayin kumesinde kararli kaliyor.

### Hesap ve guvenlik

- [ ] `QA-ACC-01` Profil adi/e-posta degisikligi, yeniden dogrulama ve eski adrese guvenlik bildirimi calisiyor.
- [ ] `QA-ACC-02` Sifre degisikligi ve hesap silme dogru parola ister; oturum/veri etkileri beklenen gibi.
- [ ] `QA-ACC-03` Aktif oturum listesi, tek oturum ve diger tum oturumlari kapatma calisiyor.
- [ ] `QA-ACC-04` Hassas auth uclarinda rate-limit mesaji gorunuyor ve hesap varligini sizdirmiyor.
- [ ] `QA-ACC-05` Eszamanli istekler atomik D1 kotasini asamiyor; Cloudflare edge reddi D1 mutation'ina ulasmadan istegi durduruyor.

### Topluluk

- [ ] `QA-COMM-01` Degerlendirme, spoiler, rapor ve yorum moderasyonu iki dogrulanmis hesapla calisiyor.
- [ ] `QA-COMM-02` Yanit/begeni/engelleme/engel kaldirma ve Studio yanit moderasyonu iki dogrulanmis hesapla calisiyor; engel global ban etkisi yaratmiyor.

### Studio operasyonu

- [ ] `QA-STU-01` Public oturum Studio'ya otomatik gecmiyor; Studio host-only oturum istiyor.
- [ ] `QA-STU-02` Icerik CRUD, panel siralama/kaldirma ve kapak geri yukleme audit kaydi olusturuyor.
- [ ] `QA-STU-03` Iletisim kutusunda mesaj durumu degisiyor; kullanici girdisi guvenli gosteriliyor.
- [ ] `QA-STU-04` Audit filtreleri ve sayfalama calisiyor; token/parola/serbest hassas metadata gorunmuyor.
- [ ] `QA-STU-05` Outbox dogrulama, sifirlama, guvenlik bildirimi ve yonetici davetini dogru etiketliyor.
- [ ] `QA-STU-06` Outbox saklama ozeti dogru sayilari gosteriyor; yalniz politika suresi dolan sentetik kayitlar temizleniyor ve audit olayi olusuyor.
- [ ] `QA-STU-07` Responsive kuyruk modu Studio'da dogru etiketleniyor; teslim hatasi hassas ayrinti sizdirmiyor ve yeniden gonderme yalniz gercek bekleyen production isleri varken gorunuyor.
- [ ] `QA-STU-08` Platform readiness ucu public hostta 404, oturumsuz Studio isteginde 401, eksik zorunlu binding'de 503 ve otomatik kontroller hazirken 200 donuyor; cevap secret veya hesap kaynak kimligi icermiyor.
- [ ] `QA-STU-09` Studio `/qa`, D1/R2 kurtarma tatbikatini `QA-OPS-02` olarak kalici hatirlatir; runbook disinda destructive restore aksiyonu sunmaz.
- [ ] `QA-STU-10` Telif bildirimi genel mesajdan ayri listelenir; durum/public yanit guncellemesi audit olayi uretir ve serbest basvuru metni audit metadata'sina sizmaz.

## Test kaydi formati

Bir madde tamamlandiginda satir veya checkbox yanina su formati ekle:

`GECTI - YYYY-AA-GG - ortam/viewport - kisa sonuc notu`

Bir hata bulunursa ilgili ID'yi issue/branch/commit mesajinda kullan. Duzeltme merge edildiginde madde tekrar `BEKLIYOR` durumuna alinir; boylece regresyon testi unutulmaz.
