# Ozgun romantik webtoon stil pilotu

## Güncel karar

Detaylı üretim standardı `korean-romance-webtoon-production-rulebook.md` dosyasına taşındı. İlk karşılaştırma varyantları araştırma artefaktı olarak korunur; `master-refined.png` artık üretim master'ı değildir. Görsel, fazla sinematik/painterly render, tek tip detay yoğunluğu ve N/C/B/E çizim modlarını kanıtlamaması nedeniyle yeni 12 karelik master testine göre reddedilmiştir.

Bu klasordeki tum gorseller 18 Temmuz 2026 tarihinde yerlesik GPT Image araci ile, tamamen ozgun karakterler ve sahne kullanilarak uretildi. Referans bolumden gorsel girdi verilmedi; telifli panel, karakter, kompozisyon veya metin kopyalanmadi.

## Karsilastirma seti

| Dosya | Amac | Sonuc |
| --- | --- | --- |
| `variant-a-airy-editorial.png` | Temiz, acik, uretilebilir romantik webtoon | En iyi okunabilirlik ve beyaz alan; haftalik uretime en yakin ilk aday |
| `variant-b-cinematic.png` | Soguk, dramatik ve derin kadraj | Etkileyici fakat fazla foto-gercekci; bolum ici tutarlilik ve maliyet riski yuksek |
| `variant-c-watercolor.png` | Sicak, yumusak ve ifade odakli suluboya | Duygusal olarak guclu; model ve doku surekliligi daha zor |
| `master-refined.png` | A'nin uretilebilirligi ile C'nin yuz oyunculugunu birlestirme | Reddedilen eski aday; yeni kural kitabı için karşılaştırma artefaktı |

`master-refined.png`, yerel web akisinda eski örneği göstermek amaciyla `Bir Bilet Uzağında / Bölüm 1: Rüzgâra Karışan` adiyla kataloga baglanmistir. Bu yayın yalnız karşılaştırma pilotudur; devam bölümü ve yeni panel üretimi için kullanılmaz.

## Ortak sahne testi

Deniz (27) ve Aras (30), yagmurdan sonra bir Istanbul feribot terminalinde ilk kez karsilasir. Ucan bos bir kagit bilet, genis plan -> iki plan -> el detayi -> bakis yakin plani dizisiyle anlatilir. Metin ve balonlar bilerek uretilmedi; dizgi ayri katmanda yapilacak.

## Master adayi kurallari

- Ince grafit-gri kontur, dogal yetiskin oranlari ve tutarli modern kiyafet.
- Kirik beyaz, soluk mint, sisli mavi, yosun yesili ve lacivert ana palet; kehribar yalniz isik vurgusu.
- Iki kademeli yumusak cel golge; suluboya doku yalniz yagmur yansimasi ve uzak atmosferde.
- Panel ilerledikce arka plan ayrintisi azalir, karakter oyunculugu artar.
- Metin, balon ve ses efekti gorsel uretimden sonra ayri ve duzenlenebilir katmanda eklenir.
- Bu dosya model sheet yerine gecmez. Seri uretiminden once yuz acilari, boy farki, el anatomisi, kiyafet ve gun/gece isik testleri gerekir.

## Prompt ozeti

Varyantlar ayni karakter ve sahne kilidiyle uretildi. Degisen tek eksenler cizgi agirligi, renk, golge, arka plan yogunlugu ve kamera diliydi:

- A: airy editorial romance; temiz ince cizgi, dusuk doygun pastel, genis beyaz bosluk.
- B: cinematic modern romance; teal/slate, dramatik dusuk aci, yansima ve alan derinligi.
- C: expressive soft watercolor; kontrollu murekkep, suluboya yikama, daha sicak yuz oyunculugu.
- Master: production-friendly clean line art; iki seviye cel golge, secici suluboya, dortlu kadraj testi ve kati karakter tutarliligi.

Tam gorsel analiz `romance-webtoon-visual-analysis.md` dosyasindadir.
