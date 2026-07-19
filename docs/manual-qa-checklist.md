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
| QA-ROLE-01 | BEKLIYOR | Kullanici rol yonetimi | Studio `/users` | Kendi rolunu degistirememe, son admin korumasi ve rol degisince hedef oturumlarin kapanmasi dogrulanmali. |
| QA-SEC-01 | BEKLIYOR | Atomik ve dagitik rate-limit | Studio `/qa`; public `/login`, `/register`, `/forgot-password`; Studio yonetici mutation'lari | Yerelde `d1_strict` etiketi gorunmeli ve kota tam sinirda reddetmeli. Production testinde `cloudflare_hybrid` etiketi gorunmeli; eksik binding fail-closed olmali ve hesap varligi sizmamali. |
| QA-ADS-01 | BEKLIYOR | Google resmi test reklami | Public reklam alanlari + Studio `/ads` | Yalniz resmi Google test birimi gorunmeli; gercek publisher veya tiklama otomasyonu olmamali. |
| QA-STU-06 | BEKLIYOR | Outbox saklama ve temizleme | Studio `/outbox` | Saklama sayilari dogru olmali; buton yalniz suresi dolan kayit varsa gorunmeli; temizlik aktif kaydi silmemeli ve audit olayi olusturmali. |
| QA-RESP-01 | BEKLIYOR | Responsive genel tur | Public ana/seri/okuyucu, auth ve Studio | 1440, 1024, 768, 390 ve 360 px'te yatay tasma, kirpik kontrol, 44 px alti dokunma hedefi veya ulasilamayan aksiyon olmamali. |

## Tam feature matrisi

### Public okuma

- [ ] `QA-PUB-01` Ana sayfa arama ve tur filtresi dogru kartlari getiriyor.
- [ ] `QA-PUB-02` Seri sayfasi basla/devam et, bolum listesi ve topluluk alanini bagliyor.
- [ ] `QA-PUB-03` Okuyucu onceki/sonraki, ilerleme, tema ve dikey panel akisinda calisiyor.
- [ ] `QA-PUB-04` Bilinmeyen seri/bolum 404; hakkimizda, iletisim ve yasal footer linkleri calisiyor.
- [ ] `QA-PUB-05` Kutuphane, favori ve hesaplar arasi okuma ilerlemesi korunuyor.

### Hesap ve guvenlik

- [ ] `QA-ACC-01` Profil adi/e-posta degisikligi, yeniden dogrulama ve eski adrese guvenlik bildirimi calisiyor.
- [ ] `QA-ACC-02` Sifre degisikligi ve hesap silme dogru parola ister; oturum/veri etkileri beklenen gibi.
- [ ] `QA-ACC-03` Aktif oturum listesi, tek oturum ve diger tum oturumlari kapatma calisiyor.
- [ ] `QA-ACC-04` Hassas auth uclarinda rate-limit mesaji gorunuyor ve hesap varligini sizdirmiyor.
- [ ] `QA-ACC-05` Eszamanli istekler atomik D1 kotasini asamiyor; Cloudflare edge reddi D1 mutation'ina ulasmadan istegi durduruyor.

### Studio operasyonu

- [ ] `QA-STU-01` Public oturum Studio'ya otomatik gecmiyor; Studio host-only oturum istiyor.
- [ ] `QA-STU-02` Icerik CRUD, panel siralama/kaldirma ve kapak geri yukleme audit kaydi olusturuyor.
- [ ] `QA-STU-03` Iletisim kutusunda mesaj durumu degisiyor; kullanici girdisi guvenli gosteriliyor.
- [ ] `QA-STU-04` Audit filtreleri ve sayfalama calisiyor; token/parola/serbest hassas metadata gorunmuyor.
- [ ] `QA-STU-05` Outbox dogrulama, sifirlama, guvenlik bildirimi ve yonetici davetini dogru etiketliyor.
- [ ] `QA-STU-06` Outbox saklama ozeti dogru sayilari gosteriyor; yalniz politika suresi dolan sentetik kayitlar temizleniyor ve audit olayi olusuyor.
- [ ] `QA-STU-07` Responsive kuyruk modu Studio'da dogru etiketleniyor; teslim hatasi hassas ayrinti sizdirmiyor ve yeniden gonderme yalniz gercek bekleyen production isleri varken gorunuyor.

## Test kaydi formati

Bir madde tamamlandiginda satir veya checkbox yanina su formati ekle:

`GECTI - YYYY-AA-GG - ortam/viewport - kisa sonuc notu`

Bir hata bulunursa ilgili ID'yi issue/branch/commit mesajinda kullan. Duzeltme merge edildiginde madde tekrar `BEKLIYOR` durumuna alinir; boylece regresyon testi unutulmaz.
