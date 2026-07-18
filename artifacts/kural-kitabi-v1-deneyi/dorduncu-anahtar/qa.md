# Dördüncü Anahtar — kural kitabı v1 QA

## Sonuç

Durum: **style-master deneyi geçti — 91/100, sıfır blocker**

Bu puan yalnız beş panellik görsel/akış deneyi içindir; 60-90 panellik bölüm üretim izni değildir. Tam bölümden önce 12 karelik sahneler-arası master testi gerekir.

| Alan | Maksimum | Puan |
| --- | ---: | ---: |
| Karakter yüz/saç/imza detay sürekliliği | 20 | 17 |
| Stil bloğuna uyum | 20 | 18 |
| Sahne, palet, ışık ve kıyafet kilidi | 15 | 14 |
| El/parmak ve anahtar nesne sürekliliği | 15 | 14 |
| Kamera rotasyonu ve görsel hikâye | 10 | 10 |
| Balon için negatif alan | 10 | 9 |
| Metin ayrımı ve 690 px şerit uygulanabilirliği | 10 | 9 |

## Panel checklist

- [x] P001 geniş kuruluş, P002 omuz üstü, P003 insert, P004 yakın yüz ve P005 gag; aynı açı art arda yok.
- [x] Selin ve Mert kıyafetleri S01 boyunca korunuyor.
- [x] Düşük doygun pastel, ince kontur ve yumuşak suluboya-gradient gölge kullanılıyor; sert cel gölge yok.
- [x] P002 ve P003'te anahtar tekil/çift reveal mantığı okunuyor.
- [x] Görsellerde yazı, balon, logo veya watermark yok.
- [x] Türkçe metin HTML/CSS overlay ve `script.json` içinde düzenlenebilir.
- [x] Gag karede saç kesimi, kıyafet ve toka tanınırlığı korunuyor.

## Reddedilen sürümler

- `MERT_turnaround-rejected-v1`: gözlük yüz ve cep arasında çoğalmıştı.
- `SELIN_outfits-rejected-v1`: toka tarafı turnaround ile kararsızdı.
- `S01_P005-rejected-v1`: chibi toka normal panelin karşı tarafındaydı.

## Karşılaştırma: Yarınki Ses'e göre

### Daha iyi

- Romantik manhwa yüz, saç teli, yumuşak renk ve atmosfer hissi belirgin biçimde daha yakın.
- Sahne bloğu sayesinde P001-P004 arasında ışık, taş pasaj ve kıyafet sürekliliği güçlü.
- Kamera rotasyonu ve sessiz obje reveal'i daha profesyonel okunuyor.
- Gag register'ı normal panellerden açıkça ayrılıyor.

### Daha riskli

- “Lots of glow/bloom” ve “photo-referenced background” ifadeleri kareleri haftalık çizgi ekonomisinden uzaklaştırıp fazla sinematik/boyanmış hale getiriyor.
- Aksesuar tarafı ve küçük imza detayları sheet aşamasında bile drift edebiliyor; iki düzeltme gerekti.
- P001 arka plan detayı production maliyetini yükseltir ve 60-90 panel boyunca tutarlılığı zorlaştırır.
- Yüzler daha çekici fakat varsayılan model güzellik estetiğine yaklaşma riski taşıyor; karakter özgünlüğü için siluet ve yüz oranı varyasyonu artırılmalı.

## Art director önerisi

Bu yön, önceki pilottan görsel olarak daha güçlü. Sonraki iterasyonda kural kitabının ana yapısını koruyup yalnız iki satırı rafine etmek mantıklı:

1. `Lots of soft white glow and bloom` → yalnız duygusal B panellerinde seçici glow.
2. `softly painted photo-referenced backgrounds` → N panellerde sadeleştirilmiş, E panellerde detaylı arka plan.

Bu değişiklikler yapılmadan 60-90 panellik üretime geçilmemeli.
