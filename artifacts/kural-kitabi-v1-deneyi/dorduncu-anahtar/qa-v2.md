# Dördüncü Anahtar — style-master v2 QA

## Sonuç

Durum: **görsel QA geçti — 92/100; kullanıcı style-master onayı bekleniyor**

Bu paket tam bölüm değildir. Amaç, kabul edilmiş karakterleri değiştirmeden arka planı foto-gerçekçi/sinematik üretimden çizgisel romance manhwa üretim gramerine taşımaktır.

| Alan | Maksimum | Puan |
| --- | ---: | ---: |
| Karakter yüz/saç/kıyafet sürekliliği | 20 | 18 |
| E/N/B/C arka plan register uyumu | 25 | 22 |
| Sahne geometrisi, palet ve ışık kilidi | 15 | 14 |
| El, ayak, anahtar ve kilit fiziksel doğruluğu | 15 | 12 |
| Kamera rotasyonu ve görsel hikâye | 10 | 9 |
| Balon için negatif alan | 10 | 8 |
| Dosya/provenance/şerit uygulanabilirliği | 5 | 5 |

## Arka plan değerlendirmesi

- P001'in ilk üretimi fazla foto-gerçekçi ve parlak kaldı; ikinci üretim fazla steril/şematikti. P001-v3, çizgisel mimari + sınırlı suluboya dengesini kurduğu için arka plan master'ı seçildi.
- P001, P006 ve P010 E panellerinde perspektif ve mekân işaretleri okunuyor; yüzeyler fotoğraf dokusu yerine ince kontur ve mat değer gruplarıyla kuruluyor.
- P002, P007 ve P011 N panelleri mekânı 1-3 işarete indiriyor. Karakter oyunculuğu arka plandan belirgin biçimde önde.
- P004, P009 ve P012 B panellerinde arka plan sadeleşiyor; v1'deki tüm kadraflı bloom yok.
- P010 yağmurlu zemininde hafif değer geçişi bulunuyor fakat v1'deki ayna yansıması ve sinematik parlama oluşmadı.
- P006'nın trabzanı diğer E panellerden daha ayrıntılı. Tam bölüm üretiminde E paneller için üst ayrıntı sınırı olarak kabul edilmeli, aşılmamalı.

## Karakter kilidi değerlendirmesi

- Selin'in koyu kestane saç, adaçayı tokası, trençkot, kömür pantolon ve bordo loafer dili korunuyor.
- Mert'in siyah dalgalı saç, lacivert overshirt, açık pantolon, cep gözlüğü ve koyu şemsiye dili korunuyor.
- V2 karakter sheet'i üretmedi; kabul edilmiş v1 sheet'leri her panelde birincil kimlik kaynağı olarak kullandı.
- Yakın planlarda yüz güzelleştirme etkisi küçük oranda sürüyor; tam bölümde yüz oranı drift kontrolü devam etmeli.

## Reddedilen/düzeltilen kareler

- P001 ilk üretim: fotoğraf hissi, detaylı cephe ve parlak zemin nedeniyle reddedildi.
- P001 ikinci üretim: fazla boş ve vektör şema gibi kaldığı için reddedildi.
- `P012-rejected-v1`: kilit kapıya bağlı değildi; karakter gövdesinin önünde yüzüyordu.
- `P012-B-v2`: kapı yüzeyi ve kilit sağ kenara fiziksel olarak bağlandı; kabul edildi.

## Kalan riskler

- E panellerinde model, yasaklara rağmen ayrıntıyı artırmaya eğilimli. Her yeni mekân için ilk E paneli ayrıca onaylanmalı.
- Ayakkabı ve metal objelerde parlaklık arka plana göre daha yüksek kalabiliyor; materyal QA ayrı yapılmalı.
- P012'de anahtar Mert'in önünden perspektif olarak geçiyor; fiziksel bağlantı doğru olsa da tam bölüm kompozisyonunda kapıya daha yakın yan açı tercih edilmeli.

## Üretim kararı

Teknik ve görsel QA eşiği geçti. Buna rağmen `script.json` durumu kullanıcı görsel onayı gelene kadar `candidate-awaiting-user-approval` kalır; seri üretim veya kataloğa ekleme yapılmaz.
