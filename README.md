# Panelya Web

Panelya, mobil-oncelikli ve Turkce bir dikey cizgi hikaye platformunun web MVP'sidir. Proje Next.js App Router, React, TypeScript ve vinext ile Cloudflare Workers uyumlu calisir.

## Baslangic

Node.js 22.13 veya uzeri gerekir.

```bash
npm install
npm run dev
```

Yerel sunucu bos olan ilk portu kullanir; terminalde yazan `Local` adresini acin.

## Kontroller

```bash
npm test
npm run lint
npm run build
```

## Urun route'lari

- `/`: kesif ve katalog
- `/gece-vardiyasi`: ornek seri sayfasi
- `/gece-vardiyasi/bolum-1`: dikey okuyucu
- `/api/catalog`: surumlu katalog JSON'u
- `/login` ve `/register`: yerel D1 hesap akisi
- `/account`: profil, sifre, cikis ve hesap silme
- `/library`: favoriler, okuma durumu ve kaldigin yer
- `http://studio.localhost:3000/`: ayri hosttaki admin paneli
- `http://studio.localhost:3000/ads`: Google test reklam laboratuvari
- `http://studio.localhost:3000/content`: D1 tabanli seri ve bolum icerik yonetimi
- `http://studio.localhost:3000/content/new`: yeni taslak seri olusturma
- `http://studio.localhost:3000/media`: doğrulamalı R2 kapak ve panel yükleme
- `http://studio.localhost:3000/messages`: lokal iletisim mesaj kutusu
- `/about`, `/creators`, `/publishing-principles`, `/production-journal`: urun ve yayin bilgileri
- `/contact`: D1'e kaydolan calisan lokal iletisim formu
- `/privacy`, `/terms`, `/copyright`: yasal bilgi ve telif rotalari

## Yerel hesap ve Studio

Ilk kaydedilen yerel hesap otomatik olarak `admin`, sonraki hesaplar `reader` olur. Bu sadece gelistirme ve test kolayligidir; production yetkilendirme modeli degildir. Yerel D1 durumu `.wrangler/` altinda tutulur ve git'e eklenmez.

Studio public siteden ayri `studio.localhost` hostunda calisir. Ayni uygulama ve D1 verisi kullanilir; ancak oturum cookie'si host-only oldugu icin Studio'ya ayrica yonetici girisi gerekir. Production hedefi `studio.<ana-domain>` seklindedir. Studio seri ve bolum CRUD akisini yonetir; `/media` ekraninda JPEG/PNG/WebP kapak veya paneller dosya imzasi, byte ve piksel sinirlariyla dogrulanip yerel R2 binding'ine yazilir. Public katalog yalniz yayindaki icerigi, public medya endpoint'i ise halen yayindaki icerige bagli asset'i sunar. Panel siralama/kaldirma ve turetilmis responsive format kuyrugu sonraki fazdir.

Ana sayfa ve seri sayfasindaki reklam alanlari Google Publisher Tag'in resmi ornek test agina baglidir. Panelya publisher kimligi, gercek kampanya, gelir veya tiklama simulasyonu yoktur. Ayrinti: [docs/ads-test-plan.md](./docs/ads-test-plan.md).

Mimari ve urun kararlari [production-bible.md](./production-bible.md), ajan gorevleri [AGENTS.md](./AGENTS.md) icindedir. `.env` yerel sirlar icindir ve repoya eklenmez.

Siradaki lokal eksikler ve oncelik sirasi [docs/local-gap-backlog.md](./docs/local-gap-backlog.md) icindedir.

## Repository ve mobil devralma

GitHub branch düzeni, büyük görsel politikası ve MacBook başlangıç adımları [docs/repository-workflow.md](./docs/repository-workflow.md) içindedir. Mobil uygulama mimarisi ve API devralma sınırları [docs/mobile-handoff.md](./docs/mobile-handoff.md) dosyasında hazırlanmıştır.

`artifacts/` altındaki ağır görsel üretim çıktıları GitHub'a gönderilmez. Web'in gerçekten kullandığı görseller optimize edilmiş WebP olarak `public/images` altında tutulur; yerel PNG/JPEG kaynaklar `scripts/optimize_public_images.py` ile yeniden dönüştürülebilir.
