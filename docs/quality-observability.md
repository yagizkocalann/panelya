# Kalite izlenebilirligi ve performans butcesi

## Amac ve sinir

Bu katman urun analitigi veya kullanici takibi degildir. Yalniz istemci kalite
sinyallerini toplamak icin saglayicidan bagimsiz bir sinir sunar:

- Core Web Vitals: `CLS`, `FCP`, `INP`, `LCP`, `TTFB`.
- Genel istemci hata turleri: global hata, route hata ekrani ve yakalanmamis
  Promise reddi.
- Build sonrasi JavaScript, CSS, Worker girisi ve Git ile izlenen public raster
  dosyalari icin deterministik boyut butcesi.

Varsayilan `QUALITY_TELEMETRY_MODE=disabled` durumunda endpoint olayi dogrular
ama saklamaz veya dis servise gondermez. `cloudflare_logs` modu yalniz production
gibi yonetilen bir ortamda, saklama ve erisim politikasi ayrica onaylandiktan
sonra acilabilir. Bilinmeyen mod fail-closed olarak `503` doner.

## Production Cloudflare politikasi

Panelya'nin ilk production gozetim katmani Cloudflare Workers Logs'tur. Worker
yapilandirmasi loglamayi acar fakat otomatik invocation loglarini kapatir.
Invocation loglari istek/yanit metadata'si tasiyabildigi icin Panelya'nin kalite
verisi minimizasyonu sinirina dahil degildir. Tracing de ilk production
surumunde acilmaz. Yalniz uygulamanin yapisal `panelya.quality` kayitlari ile
serbest metin tasimayan operasyonel hata adlari saklanir.

| Karar | Production degeri |
| --- | --- |
| Workers Logs | Acik |
| Invocation logs | Kapali (`invocation_logs: false`) |
| Custom log sampling | `%100`; endpoint zaten GPC/DNT, same-origin ve allowlist ile sinirli |
| Tracing | Kapali; ayri veri/butce karari olmadan acilmaz |
| Cloudflare dashboard saklama | Plana bagli dogal sure: Free 3 gun, Paid 7 gun; Panelya dis export yapmaz ve 7 gunden uzun tutmaz |
| Erisim | Hesap sahibi ve acikca atanmis production incident yoneticileri; genel ekip/paylasilmis link yok |
| Export | Varsayilan kapali; JSON/CSV, Logpush, OTel veya ucuncu taraf aktarimi ayri onay ister |

Cloudflare saklama suresi uygulama icinden uzatilamaz; planin dogal silinmesi
kullanilir. Daha uzun saklama isteyen bir gelecek karar, yeni veri envanteri,
erisim rolleri, maliyet ve silme politikasiyla birlikte ele alinir.

### Kaydedilecek sorgular

Production Worker olustuktan sonra hesap seviyesinde su sorgular kaydedilir:

1. `Panelya - istemci hatalari`: `eventType = panelya.quality` ve
   `kind = client_error`; sayim `name` ve `path` ile gruplanir.
2. `Panelya - kotu web vitals`: `eventType = panelya.quality`,
   `kind = web_vital`, `rating = poor`; sayim `name` ve `path` ile gruplanir.
3. `Panelya - Worker 5xx`: Worker response status `500-599`; sayim route ve
   status ile gruplanir. Invocation loglari kapali oldugundan bu sorgu ancak
   Cloudflare'in hesap/zone metrik yuzeyinde kullanilir; uygulama custom loguna
   request metadata'si eklenmez.

### Alarm politikasi

- Public production domain Cloudflare proxy arkasina alindiginda Notifications
  altinda `5xx Error Rate` e-posta alarmi acilir. Ilk trafik dusuk olacagi icin
  `Low sensitivity` kullanilir; tekil hata bildirim firtinasi olusturulmaz.
- CPU limiti, deployment hatasi ve beklenmeyen Worker exception'i Cloudflare
  Worker metrikleri/Observability ekranindan incelenir. Error `1101` ve `1102`
  olaylari yayin bloklayici kabul edilir.
- Kaydedilmis Observability sorgulari alarm degildir. `panelya.quality` icin
  otomatik esik gerekiyorsa Paid/Enterprise Tail Worker veya onayli harici
  saglayici ayri kararla kurulur; ilk surumde haftalik manuel trend incelemesi
  yapilir.

### Production etkinlestirme sirasi

1. Sites/Cloudflare production projesini olustur ve gercek public HTTPS domaini
   bagla; D1/R2 ve diger zorunlu binding readiness kontrollerini gec.
2. Derlenmis `dist/server/wrangler.json` icinde `observability.enabled=true`,
   `logs.invocation_logs=false` ve `logs.head_sampling_rate=1` oldugunu dogrula.
3. `QUALITY_TELEMETRY_MODE=cloudflare_logs` degerini yalniz production runtime'a
   ekle; preview/local varsayimi `disabled` kalir.
4. Bir sentetik `client_error` ve bir `poor` web-vital olayi gonder; dashboardda
   yalniz allowlist alanlarinin gorundugunu ve request metadata'sinin custom loga
   girmedigini denetle.
5. Uc kayitli sorguyu ve dusuk hassasiyetli 5xx e-posta alarm politikasini kur;
   teslim kanalini sentetik 5xx smoke ile dogrula.

## Veri minimizasyonu

`POST /api/quality` yalniz surumlu allowlist govdesini kabul eder. Kullanici,
oturum, e-posta, IP, user-agent, referrer, query/hash, hata mesaji, stack trace,
token veya serbest metin almaz. Gizli onizleme ve telif durum rotalarindaki
anahtar bolumu maskelenir. Body 2 KiB ile sinirlidir ve istek same-origin olmak
zorundadir.

Tarayici `Global Privacy Control` veya `Do Not Track: 1` bildirirse istemci hic
kalite istegi gondermez. Bu sinir daha sonra bir hata/analitik saglayicisi
eklenirse de korunur; adapter ham request veya exception alamaz.

## Esikler ve CI butcesi

Web vital dereceleri yaygin Core Web Vitals esiklerini kullanir. Kesin build
butceleri `docs/performance-budgets.json` dosyasinda surumlenir. Kontrol:

```text
npm run build
npm run perf:budget
```

Butce artisinin kendi basina yapilmasi kabul edilmez. Artis gerekiyorsa olculen
neden, kullanici etkisi ve geri alma karari ayni PR'da belgelenir. Buyuk bolum
panelleri ve Studio kaynak medyasi bu statik public raster kontrolunun disindadir;
onlar mevcut R2 yukleme/varyant sinirlariyla denetlenir.

## Hata kurtarma

Route ve global hata ekranlari teknik ayrinti gostermeden calisan `Tekrar dene`
ve `Ana sayfaya don` aksiyonlari sunar. Hata metni veya stack telemetry'ye
girmez. Kontroller en az 44 px ve klavye focus'u gorunur kalir.

## Kalan dis is

- Urun analitigi olay sozlugu, dashboard ve erisim/saklama politikasi.
- Onayli bir hata izleme saglayicisi gerekiyorsa ayni allowlist sinirinin adapteri.
- Reklam gorunurluk olcumu ve consent/CMP baglantisi.
- Production Worker/public domain olustuktan sonra Cloudflare dashboard kayitli
  sorgularini ve 5xx e-posta alarm teslimini canli dogrulamak.
