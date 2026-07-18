# Panelya lokal eksik listesi

## P0 - Siradaki ana teslimat

0. Tamamlandi: Studio public siteden ayri hostta calisir (`studio.localhost`; production hedefi `studio.<ana-domain>`), host-only yonetici oturumu kullanir.
1. Tamamlandi: Studio seri/bolum CRUD, taslak-yayin-arsiv durumu, one cikarma ve mutation audit kayitlari.
2. Tamamlandi: public katalog D1 tablolarindan okunur; typed seed baslatma/geri dusus olarak kalir ve API sozlesmesi korunur.
3. Tamamlandi: yerel R2 binding'i ile kapak/panel yukleme, dosya imzasi, MIME, byte ve piksel kontrolu, D1 metadata ve yayinla sinirli public servis.
4. Tamamlandi: panel siralama, Studio'dan yuklenen panel baglantisini R2 kaynagini silmeden kaldirma ve kapak gecmisinden geri yukleme.
5. Siradaki: turetilmis responsive format kuyrugu.
6. Siradaki: yayinlanmamis icerik icin guvenli taslak onizleme baglantisi.

## P1 - Okuyucu ve topluluk

1. Seri sayfasinda kutuphane/favori butonlarinin aktif durumunu sunucudan gostermek.
2. Yorum yanitlari, begeni ve kullanici engelleme tercihleri.
3. Takip edilen seriler ve yeni bolum bildirim tercihleri.
4. D1 tabanli arama, siralama, filtreleme ve cursor pagination.

## P1 - Hesap ve guvenlik

1. Admin daveti, rol yonetimi ve ilk-kullanici-admin kuralinin kaldirilmasi.
2. Production kimlik ve e-posta saglayicisi ile KVKK/GDPR saklama politikasinin kesinlestirilmesi.
3. Yerel sabit-pencere limitini edge/WAF veya dagitik rate-limit katmanina tasima.
4. Idle session timeout ve yuksek riskli islemlerde yeniden kimlik dogrulama politikasini kesinlestirme.

## P1 - Operasyon ve gelir

1. Gercek reklam hesabi gecisinden once CMP/onay yonetimi ve canli/test ortam ayrimi.
2. Analitik, hata izleme, performans butcesi ve reklam gorunurluk olcumleri.
3. Studio audit ekranı, veri yedegi ve geri yukleme proseduru.
4. Sitemap, robots, canonical ve Series JSON-LD.

## P2

1. Tamamlandi: GPT Image ile ozgun `Yarınki Ses` pilotunun 18/18 panel uretimi, QA ve public okuyucu yayini.
2. Web akisi sabitlendikten sonra Flutter mobil uygulamasi (ADR-019).
3. Deep link, cevrimdisi okuma ve push bildirimleri.

## Su anda tamamlanan etkilesim yuzeyi

- Giris/uyelik geri ve kapat kontrolleri.
- Footer'daki tum kurumsal ve yasal rotalar.
- Lokal iletisim formu ve Studio mesaj durumu yonetimi.
- Studio seri/bolum icerik yonetimi, R2 medya yukleme, D1 yayin akisi ve reklam laboratuvari.
- Yerel e-posta outbox adaptoru, e-posta dogrulama ve sifre sifirlama.
- E-posta degisikliginde yeniden dogrulama ve eski adrese guvenlik bildirimi.
- Aktif oturum listesi, tekil/toplu oturum kapatma ve auth rate limit.
- Puanlama, yorum, spoiler gizleme, raporlama ve Studio moderasyon kuyrugu.
- Gorunur disabled/placeholder aksiyonlarin kaldirilmasi.
