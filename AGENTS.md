# AGENTS.md

## Zorunlu baslangic

Her gorevde once `production-bible.md` ve bu dosyayi oku. `.env` degerlerini yazdirma, loglama veya dokumante etme. Referans sitenin telifli gorsel/metinlerini indirme ya da repoya kopyalama.

## Model dagitimi

- Sol / high: PLAN, production bible, hikaye beat'leri, stil secimi, yeni stilin master kontrolu, mimari ADR ve yuksek riskli review.
- Terra / medium: rutin kod duzeltmesi, JSON/dokuman guncellemesi, component/API uygulamasi ve test fixleri. Varsayilan.
- Luna / low: fan-out, log/kare sayimi, kuyruk operasyonu ve mekanik dogrulama. Luna kullanilamiyorsa Terra / low.
- Ultra kullanma.
- Uretici/yazarlik isini Luna'ya; log/kare sayimi gibi mekanik isi Sol'a verme.

## Sahiplik

- Producer: urun hedefi, PLAN ve acceptance criteria. Sol/high.
- Story: premise, beat, karakter ark ve bolum ritmi. Sol/high.
- Art director: stil adaylari ve style-master tutarliligi. Sol/high.
- Web implementer: App Router, components, CSS, Route Handlers. Terra/medium.
- QA operator: route matrisi, log tarama, viewport ve kare sayimi. Luna/low ya da Terra/low.
- Mobile implementer: yalniz P0 web tamamlaninca Expo Router. Terra/medium; mimari degisiklik Sol/high review.

## Kod kurallari

- TypeScript strict; server-first. Yalnizca gercek etkileşim gereken component'e `use client` ekle.
- Tek kaynak: katalog/domain verisi `app/data` altinda; sayfalar veri kopyalamaz.
- Public route'lar: urun route'larina ek olarak `/about`, `/creators`, `/publishing-principles`, `/production-journal`, `/contact`, `/privacy`, `/terms`, `/copyright`, `/api/*`.
- Studio ayri hostta calisir: production hedefi `studio.<ana-domain>`, yerel hedef `studio.localhost`. Dis URL'ler `/`, `/content`, `/messages`, `/ads`, `/outbox`, `/moderation`; kaynak route'lari `app/studio` altinda kalir.
- Studio oturumu host-only cookie kullanir; public oturum otomatik paylasilmaz. Yonetici mutation'lari yalniz Studio hostundaki `/api/admin/*` uclarindan kabul edilir.
- Ilk kullaniciyi admin yapan kural sadece yerel QA icindir; production varsayimi yapma.
- Reklam QA'sinda yalniz Google'in resmi ornek test birimini kullan; gercek publisher kimligiyle otomatik test, yenileme veya tiklama yapma.
- Tiklanabilir gorunen placeholder/disabled buton birakma. Uygulanmayan aksiyonu buton gibi gosterme; gorunen tum link ve butonlari route/mutation/etkilesim testiyle dogrula.
- Erisilebilir semantik HTML, gorunur focus ve `prefers-reduced-motion` zorunlu.
- Mobilde 44 px altinda dokunma hedefi olmasin.
- Yeni dependency gerekcesiz eklenmez. Ortam komutlari Windows ve CI'da cross-platform calisir.

## Tamamlama tanimi

1. Ilgili acceptance criteria karsilandi.
2. Test, lint ve build basarili.
3. Degisen akis yerel tarayicida PC monitor, tablet dikey/yatay ve mobil genislikte dogrulandi.
4. Console error ve bozuk link yok.
5. Mimari veya urun davranisi degistiyse `production-bible.md` guncellendi.

## Ajan teslim formati

- Sonuc
- Degisen dosyalar
- Calistirilan kontroller ve sonuc
- Kalan risk/varsayim

## Guvenli paralellik

Ayni dosyayi iki ajan ayni anda degistirmez. Mekanik audit ajanlari read-only kalir. Ana ajan, merge oncesi `git diff` ve kalite kapilarini kontrol eder.
