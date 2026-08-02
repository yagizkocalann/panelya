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
- Production log saklama suresi, erisim rolleri ve alarm esikleri.
