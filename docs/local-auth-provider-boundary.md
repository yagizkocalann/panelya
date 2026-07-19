# Yerel auth ve saglayiciya gecis siniri

## Bugun calisan yerel dikey dilim

- Kayit, giris, cikis ve HttpOnly/SameSite oturum cookie'si.
- E-posta dogrulama baglantisi: 24 saat, tek kullanim.
- Sifre sifirlama baglantisi: 30 dakika, tek kullanim; basarida tum oturumlar kapanir.
- Mevcut sifreyle e-posta degistirme; yeni adres yeniden dogrulanir ve eski adrese guvenlik bildirimi duser.
- Aktif oturum listesi, tek oturum ve diger tum oturumlari kapatma.
- Hassas isteklerde eszamanli talepleri atomik sayan D1 kesin kota; production icin opsiyonel Cloudflare edge ani trafik kalkani.
- Studio `/studio/outbox`, gercek e-posta yerine kullanilan admin-only yerel kutu.

## Saglayici baglanirken degisecek katman

`app/lib/notifications.ts` icindeki `NotificationDelivery` sozlesmesine production adaptoru eklenir. Route'lar, token omru, hesap akisi ve UI degismez. Production adaptoru API anahtarini yalniz sunucu ortamindan okur; basarisiz gonderimler icin yeniden deneme/dead-letter ve provider message id alanlari eklenir.

## Production oncesi zorunlu kararlar

1. Uygulama-ici yerel auth yerine yonetilen identity saglayicisi veya sertlestirilmis auth servisi secimi.
2. PBKDF2 parametreleri ve parola gecis stratejisi icin guvenlik incelemesi; gerekirse Argon2id saglayan servis/runtime.
3. Tamamlandi: D1 kesin kotayi atomiklestirme ve production'da Cloudflare Rate Limiting binding'ini ani trafik kalkani olarak one ekleyen fail-closed hibrit adapter. Binding/namespace deployment ortaminda ayrica provision edilir.
4. Dogrulanmis gonderen domain, SPF/DKIM/DMARC, bounce/complaint isleme ve teslimat gozlemi.
5. Outbox ham action URL saklamasini production'da kapatma; gercek saglayiciya gonderim sonrasi yalniz operasyonel metadata tutma.
6. Session idle/absolute timeout, cihaz adlandirma ve yuksek riskli aksiyonlarda yeniden kimlik dogrulama politikasi.

## Guvenlik notlari

- Veritabaninda hesap tokeninin kendisi degil SHA-256 ozeti tutulur.
- Sifre sifirlama istegi kayitli/kayitsiz adres icin ayni kullanici mesajini dondurur.
- Reset ve dogrulama sayfalari tokeni baska origin'lere tasimayan `same-origin` referrer politikasini kullanir; bu, form POST'larinin local dev origin kontroluyle uyumlu kalmasini saglar.
- POST mutasyonlari `Origin` eslesmesiyle; Origin gondermeyen form navigasyonlari ise yalniz `Sec-Fetch-Site: same-origin` kanitiyla kabul edilir.
- Yerel outbox action URL'leri API/log ciktisina yazilmaz; Studio formu id uzerinden guvenli redirect yapar.
