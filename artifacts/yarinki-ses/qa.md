# Yarınki Ses — görsel QA

## Master kapısı

Durum: **geçti — 93/100, sıfır blocker**

| Alan | Maksimum | Puan |
| --- | ---: | ---: |
| Karakter/model sürekliliği | 20 | 18 |
| Çizgi, renk ve mod tutarlılığı | 15 | 13 |
| Anatomi, el ve nesne teması | 15 | 14 |
| Yüz/beden oyunculuğu | 15 | 14 |
| Dikey ritim ve reveal | 15 | 14 |
| Diyalog/lettering alanı | 10 | 10 |
| Mekân/eksen sürekliliği | 5 | 5 |
| Export/mobil bütünlük | 5 | 5 |

Yayın eşiği: 85/100 ve sıfır blocker.

## Blocker kontrolü

- [x] El/parmak anatomisi temiz.
- [x] Derya saç, yüz ve kıyafet kilidi korunuyor.
- [x] Baran saç, yüz ve kıyafet kilidi korunuyor.
- [x] N modu fazla painterly değil.
- [x] C modu aynı karakterleri koruyor.
- [x] B modu güzellik reklamı pozu değil, hikâye duygusu taşıyor.
- [x] Balonlar için güvenli negatif alan var.
- [x] Görsel içinde model üretimi yazı/logo/watermark yok.
- [x] Referans esere ayırt edici karakter veya kompozisyon benzerliği yok.

## QA notları

- Kabul paketi: 18/18 panel. Her kabul edilen PNG'nin metadata içermeyen `-clean.png` kardeşi var.
- Panel 005 v1, kurucu planda Baran'ı zamanından önce gösterdiği için reddedildi; v2 yalnız Derya'yı kullanır.
- Panel 009 v1, iki elin aynı rüzgârlığa uzandığını yeterince açık göstermediği için reddedildi; v2 nesneyi parmakların merkezine alır.
- Panel 012 v1, elektronik field recorder yerine müzik aleti ürettiği için reddedildi; v2 dikdörtgen dijital cihaz kilidini korur.
- Paneller sessiz üretildi. Türkçe anlatıcı ve diyalog metni okuyucuda ayrı HTML katmanıdır; yanlış model yazısı veya dile gömülü raster metin yoktur.
- Kalan küçük risk: yakın planlarda cihazın düğme yerleşimi birebir teknik model gibi sabit değil. Hikâye açısından cihaz silueti, ekran ve kırmızı LED sürekliliği korunuyor; sonraki bölümden önce ayrı cihaz model sheet'i önerilir.
