# Panelya lokal eksik listesi

## P0 - Siradaki ana teslimat

0. Tamamlandi: Studio public siteden ayri hostta calisir (`studio.localhost`; production hedefi `studio.<ana-domain>`), host-only yonetici oturumu kullanir.
1. Tamamlandi: Studio seri/bolum CRUD, taslak-yayin-arsiv durumu, one cikarma ve mutation audit kayitlari.
2. Tamamlandi: public katalog D1 tablolarindan okunur; typed seed baslatma/geri dusus olarak kalir ve API sozlesmesi korunur.
3. Tamamlandi: yerel R2 binding'i ile kapak/panel yukleme, dosya imzasi, MIME, byte ve piksel kontrolu, D1 metadata ve yayinla sinirli public servis.
4. Tamamlandi: panel siralama, Studio'dan yuklenen panel baglantisini R2 kaynagini silmeden kaldirma ve kapak gecmisinden geri yukleme.
5. Tamamlandi: yuklemede 480/768/1200 px WebP islerini D1'e ekleyen, yerelde Studio tarayicisinda isleyen, sonucu R2 varyanti olarak kaydeden ve public/preview `srcset` teslimine baglayan responsive format kuyrugu.
6. Tamamlandi: seri veya tek bolum kapsamli, 30 dakika sureli, iptal edilebilir ve ham anahtari saklanmayan guvenli taslak onizleme baglantisi; taslak R2 medyasi no-store token endpoint'iyle sunulur.

## P1 - Okuyucu ve topluluk

1. Seri sayfasinda kutuphane/favori butonlarinin aktif durumunu sunucudan gostermek.
2. Yorum yanitlari, begeni ve kullanici engelleme tercihleri.
3. Takip edilen seriler ve yeni bolum bildirim tercihleri.
4. D1 tabanli arama, siralama, filtreleme ve cursor pagination.

## P1 - Hesap ve guvenlik

1. Tamamlandi: Studio kullanici envanteri, guvenli admin/okuyucu rol degisikligi, kendi rolunu ve son admini koruma, rol degisikliginde oturum kapatma.
2. Tamamlandi: 24 saatlik tek kullanimlik admin daveti, yenileme/iptal/kabul akisi; production public kaydinda otomatik admin yetkisinin kaldirilmasi ve sifir admin kosullu tek seferlik Studio bootstrap.
3. Tamamlandi: bildirim adapter fabrikasi, tanimsiz modda fail-closed davranis ve outbox ham baglanti/guvenlik verisi icin 24 saat/48 saat/30 gunluk yerel saklama-purge politikasi. Siradaki: production kimlik ve canli e-posta saglayicisi secimi ile genel KVKK/GDPR veri envanteri.
4. Tamamlandi: mevcut uzun pencere kotalarini atomik D1 sayaciyla kesinlestirme; production'da Cloudflare Rate Limiting binding'ini lokasyon bazli ani trafik kalkani olarak one ekleyen fail-closed hibrit adapter.
5. Idle session timeout ve yuksek riskli islemlerde yeniden kimlik dogrulama politikasini kesinlestirme.

## P1 - Operasyon ve gelir

1. Gercek reklam hesabi gecisinden once CMP/onay yonetimi ve canli/test ortam ayrimi.
2. Analitik, hata izleme, performans butcesi ve reklam gorunurluk olcumleri.
3. Tamamlandi: filtrelenebilir, cursor tabanli ve guvenli metadata allowlist'i kullanan Studio audit ekrani.
4. Tamamlandi: D1 Time Travel + uzun sureli SQL export, ayri immutable R2 yedek kovasi, surumlu kurtarma paketi verifier'i ve izole geri yukleme tatbikati runbook'u. Kalan dis is: production yedek kovasi/kimligi, retention lock ve zamanlanmis export-copy workflow'unu provision edip `QA-OPS-02` tatbikatini calistirmak.
5. Sitemap, robots, canonical ve Series JSON-LD.
6. Tamamlandi: D1/R2/Images/Queue/rate-limit binding ve runtime modlarini secret sizdirmadan denetleyen Studio platform readiness kapisi. Kalan dis is: gercek Queue consumer/DLQ ve edge namespace provision/smoke testi.

## P2

1. Tamamlandi: GPT Image ile ozgun `Yarınki Ses` pilotunun 18/18 panel uretimi, QA ve public okuyucu yayini.
2. Web akisi sabitlendikten sonra Flutter mobil uygulamasi (ADR-019).
3. Deep link, cevrimdisi okuma ve push bildirimleri.

## Su anda tamamlanan etkilesim yuzeyi

- Giris/uyelik geri ve kapat kontrolleri.
- Footer'daki tum kurumsal ve yasal rotalar.
- Lokal iletisim formu ve Studio mesaj durumu yonetimi.
- Studio seri/bolum icerik yonetimi, R2 medya yukleme, D1 yayin akisi ve reklam laboratuvari.
- Studio medya ekraninda kalici responsive turetme kuyrugu, hata/yeniden deneme durumu ve varyant envanteri.
- Studio kullanici/rol yonetimi ve guvenli metadata gosteren audit gunlugu.
- Studio yonetici daveti, yerel outbox teslimi ve production ilk-yonetici bootstrap siniri.
- Studio seri/bolum ekranindan guvenli taslak onizleme baglantisi uretme, durumunu gorme ve iptal etme.
- Yerel e-posta outbox adaptoru, e-posta dogrulama ve sifre sifirlama.
- Studio outbox saklama ozeti, suresi dolan kayitlari admin-only temizleme ve vendor-bagimsiz bildirim adapter secimi.
- E-posta degisikliginde yeniden dogrulama ve eski adrese guvenlik bildirimi.
- Aktif oturum listesi, tekil/toplu oturum kapatma ve auth rate limit.
- Puanlama, yorum, spoiler gizleme, raporlama ve Studio moderasyon kuyrugu.
- Gorunur disabled/placeholder aksiyonlarin kaldirilmasi.
