# Geçici veri bakım runbook'u

## Kapsam

Bu bakım yalnız yaşam süresi ürün veya güvenlik protokolü tarafından zaten
kesinleştirilmiş D1 kayıtlarını fiziksel olarak temizler:

- süresi veya boşta kalma süresi dolmuş public/Studio oturumları;
- süresi dolmuş e-posta doğrulama ve parola sıfırlama anahtarları;
- süresi dolmuş hesap yeniden doğrulama istekleri ve tek kullanımlık kanıtlar;
- süresi dolmuş taslak önizleme anahtarları;
- reset zamanı geçmiş atomik rate-limit kovaları;
- ADR-026'nın sürümlü saklama politikasına göre temizlenebilir outbox kayıtları.

Kabul edilmiş/iptal edilmiş yönetici davetleri, audit olayları, iletişim ve telif
vakaları, yorumlar, hesap silme saga kayıtları veya medya işleri bu bakımın
kapsamına girmez. Bunlar için hukuk ve operasyon onayı olmadan süre uydurulmaz.

## Otomatik çalışma

Worker `17 3 * * *` Cron Trigger'ı ile her gün 03:17 UTC'de `scheduled()`
handler'ını çalıştırır. Cron ifadesi UTC olarak yorumlanır. Handler aynı sürümlü
politikayı kullanır ve loga yalnız politika sürümü ile toplam silinen kayıt
sayısını yazar; kullanıcı, e-posta, token, tablo anahtarı veya ham hata metni
yazmaz.

Cloudflare'ın resmi Cron Trigger sözleşmesine göre production deployment
sonrasında Worker ayarlarında tetikleyicinin göründüğü ve son çalışmanın başarılı
olduğu ayrıca kontrol edilir. Yerel testte Cloudflare Vite eklentisinin
`/cdn-cgi/handler/scheduled` test ucu kullanılabilir; gerçek veya geri alınamaz
veri yerine yalnız sentetik süresi dolmuş kayıtlar hazırlanır.

## Studio yedek tetikleyicisi

Studio `/qa` ekranı kategori bazında yalnız temizlenebilir kayıt sayılarını
gösterir. Manuel temizlik:

- yalnız `studio.<domain>`/`studio.localhost` hostunda;
- admin oturumuyla;
- same-origin istekle;
- son 10 dakikada doğrulanmış kimlikle;
- saatlik kesin D1 rate-limit sınırıyla çalışır.

Audit olayında yalnız toplam silinen kayıt ve politika sürümü bulunur. Kategori
ve kişi bazında kayıt tutulmaz.

## Production doğrulaması

1. Migration `0019` ile hesap anahtarı expiry ve rate-limit reset indekslerinin
   uygulandığını doğrula.
2. Bir sentetik süresi dolmuş kayıt ile bir aktif kayıt oluştur.
3. Zamanlanmış test handler'ını çalıştır; yalnız süresi dolan kayıt silinmeli.
4. Aynı kontrolü Studio `/qa` yedek düğmesiyle tekrarla; audit olayı oluşmalı.
5. Production Worker panelinde Cron Trigger, son başarılı çalışma ve sadece
   allowlist bakım logunun bulunduğunu doğrula.
6. Hata durumunda kullanıcı verisini loglamadan Worker hata metriğini incele;
   bakım başarısızlığı diğer fetch/Queue isteklerini başarılı göstermez.

Kaynak: [Cloudflare Cron Triggers](https://developers.cloudflare.com/workers/configuration/cron-triggers/)
ve [Scheduled Handler](https://developers.cloudflare.com/workers/runtime-apis/handlers/scheduled/).
