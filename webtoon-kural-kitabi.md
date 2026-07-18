# WEBTOON ÜRETİM KURAL KİTABI
### AI Webtoon Pipeline — Görsel Tutarlılık ve Hikâye Anayasası (v1)

Bu doküman, GPT image modeliyle webtoon bölümü üretirken **her üretimde uyulacak** kuralları tanımlar.
Referans estetik: modern Kore romance manhwa'sı ("I Want to Be Fooled" bölüm 1 analizinden çıkarılmıştır).

---

## 0. PIPELINE ÖZETİ (üretim sırası)

1. **Karakter sheet'leri üret** (bölüm üretiminden ÖNCE, bir kez) → kaydet, tüm seride referans olarak kullan.
2. **Sahne planı çıkar**: bölüm senaryosu → sahne listesi → panel listesi (her panel: kamera açısı + aksiyon + balon metni).
3. **Panelleri tek tek üret**: her prompt = STİL BLOĞU + SAHNE BLOĞU + KARAKTER BLOĞU + PANEL TARİFİ. Referans görsel olarak ilgili karakter sheet'leri + aynı sahnenin önceki paneli verilir.
4. **Kod ile birleştir**: 690px genişlik, dikey şerit, boşluk kuralları (Bölüm 6).
5. **Balon + metin ekle** (Bölüm 7 — varsayılan yöntem: kod overlay).
6. **Kalite kontrol** (Bölüm 10 checklist) → geçemeyen panel yeniden üretilir.

> Altın kural: **Model asla "bölüm" üretmez, her zaman TEK PANEL üretir.** Kompozisyon, akış ve tempo kodun ve senaryonun işidir.

---

## 1. STİL ANAYASASI (her prompt'un başına aynen eklenir)

Bu blok **hiç değiştirilmeden** her panel prompt'unun başına konur. Tutarlılığın ilk yarısı budur.

```
STYLE BLOCK (do not deviate):
Modern Korean romance webtoon (manhwa) art style. Thin, clean, delicate lineart
with slightly varying line weight. Muted low-saturation pastel palette, soft
airy watercolor-like gradient shading — NO hard cel shading, NO screentones,
NO western comic style, NO heavy black shadows. Realistic body proportions
(about 8 heads tall), elegant elongated figures. Hair drawn with fine
individual strands and soft gradient sheen. Faces: small nose and mouth,
large expressive detailed eyes with soft highlights, subtle blush on cheeks.
Backgrounds: minimal, softly painted, heavily blurred with shallow depth of
field, desaturated, always less detailed than the characters; focus always on
characters. Lots of soft white glow and bloom around characters.
Overall mood: soft, dreamy, cinematic.
```

**Yasaklılar listesi** (negatif talimat olarak da eklenebilir):
anime screentone, 3D render, photorealism, chibi (gag panelleri hariç — Bölüm 5.4), kalın dış kontur, aşırı doygun renk, batı çizgi roman gölgelemesi, metin/yazı (overlay yönteminde).

---

## 2. KARAKTER SİSTEMİ

### 2.1 Karakter Kimlik Bloğu (metin)
Her karakter için **sabit, kelimesi kelimesine kopyalanan** bir tanım bloğu yazılır. Serbest tarif YASAK — her prompt'ta aynı blok kullanılır.

Şablon:
```
[CHAR:<ID>] <İsim>, <yaş> yaşında <cinsiyet>.
SAÇ: <renk, kesim, uzunluk, ayrım yönü, kâkül biçimi> (asla değişmez)
YÜZ: <göz rengi/biçimi, kaş, ayırt edici detay: ben, gözlük, küpe...>
VÜCUT: <boy izlenimi, yapı>
İMZA DETAY: <onu her panelde tanıtan 1-2 şey: kolye, saat, çanta...>
```

Örnek (bu formatta doldurulacak):
```
[CHAR:MIRA] Mira, 24 yaşında kadın.
SAÇ: Simsiyah, çene hizasında küt bob, ortadan hafif sağa ayrık, seyrek uzun kâkül.
YÜZ: Koyu kahve iri gözler, düz kalın kaş, sol göz altında küçük ben.
VÜCUT: Orta boy, ince, hafif kambur duruş.
İMZA DETAY: İnce gümüş kolye, hep taşıdığı bej omuz çantası.
```

### 2.2 Karakter Sheet Üretimi (seri başına bir kez)
Referans görselleri modelin kendisi üretir, sonra tüm panellerde referans olarak geri verilir.

Her ana karakter için üretilecek sheet'ler:
1. **Turnaround sheet**: aynı görselde önden / 3-çeyrek / profilden büst, nötr ifade, düz açık gri zemin.
2. **İfade sheet'i**: aynı yüz 6 ifadeyle (nötr, gülümseme, şaşkın, utanmış, kızgın, üzgün), 2×3 grid.
3. **Kıyafet sheet'i**: sahnelerde giyeceği 2-4 kıyafetle tam boy, yan yana, düz zemin.

Sheet prompt şablonu:
```
{STYLE BLOCK}
Character reference sheet on plain light-gray background, no text, no logos.
{KARAKTER KİMLİK BLOĞU}
Layout: <turnaround / expression grid / outfit lineup tarifi>
```

**Kural:** Sheet beğenilmeden seri üretime geçilmez. Sheet bir kez onaylandıktan sonra **asla yeniden üretilmez** (yenilenirse tüm seri tutarlılığı sıfırlanır).

### 2.3 Panel üretiminde referans kullanımı
- Panelde görünen **her karakterin turnaround sheet'i** referans görsel olarak eklenir.
- Mümkünse **aynı sahnenin bir önceki paneli** de referans verilir (ışık + kıyafet sürekliliği için).
- Prompt'ta referansa açıkça bağlanılır: `Match the face, hairstyle and outfit of [CHAR:MIRA] exactly as in the reference image.`

### 2.4 Yan karakterler / figüranlar
- İsimli yan karakterler de kimlik bloğu alır (sheet üretimi opsiyonel, en az turnaround önerilir).
- Figüranlar bilerek **siluet/az detaylı** çizdirilir: `background characters simplified, low detail, muted` — referans eserde de kalabalık hep flu/basit. Bu hem tutarlılık derdini azaltır hem stile uygundur.

---

## 3. SAHNE KİLİDİ (Scene Lock)

Her sahne için bir **SAHNE BLOĞU** yazılır ve o sahnenin TÜM panellerinde aynen tekrarlanır. Referans eserdeki tutarlılığın ikinci yarısı budur: sahne boyunca palet, ışık ve kıyafet kilitlidir.

```
SCENE BLOCK [S<no>]:
MEKÂN: <kısa tarif — ör. loş bar, ahşap masalar, arka planda bar tezgâhı>
ZAMAN/IŞIK: <gece, soğuk mavi-gri ambiyans, sıcak nokta ışıklar>
PALET: <3-5 renk kilidi — ör. mavi-gri baskın, kirli beyaz, bir vurgu rengi>
KIYAFET: [CHAR:X] <kıyafet>, [CHAR:Y] <kıyafet>  (sahne boyunca değişmez)
```

Palet kilidi örnekleri (referans eserden):
- Ev/oda + samimi an → sıcak pembe/krem/şeftali
- Bar/gece içmece → soğuk mavi-gri + sıcak nokta ışık
- Gece sokağı/gerilim → koyu teal, lacivert, neon lekeler
- Rüya/hayal → parlak camgöbeği, yüksek parlaklık, bol bloom

---

## 3.5 ARKA PLAN SİSTEMİ (AI görünümünü öldüren bölüm)

AI arka planlarının "yapay" durmasının sebebi her panele detaylı mekân çizdirmeye çalışmaktır.
Gerçek webtoon'lar tam tersini yapar: **mekân sahne başına 1-2 panelde kurulur, gerisi gizlenir.**
Referans eserde bile kitapçı ve bar sahnelerinin panellerinin çoğunda gerçek arka plan yoktur.

### 3.5.1 Üç kademeli arka plan sistemi (her panel birine atanır)

| Kademe | İçerik | Sahnedeki oran |
|---|---|---|
| **T1 — Kuruluş** | Gerçek mekân görünür (geniş plan). Sahne başına **en fazla 1-2 panel.** | ~%10 |
| **T2 — Bokeh/İma** | Mekân sadece ağır blur'lu renk-şekil lekeleri olarak hissedilir (raf lekeleri, ışık noktaları). Karakter net, arka plan tamamen flu. | %20-30 |
| **T3 — Soyut/Boş** | Arka plan yok: düz renk alanı, yumuşak gradyan, beyaz/siyah zemin veya duygu dokusu (ışıltı, çiçek deseni, karanlık bulut, odak çizgileri). | **%60-70** |

> Kural: Sahne T1 ile açılır, okuyucu mekânı bir kez görür, sonra T2/T3'e geçilir.
> Yakın plan ve diyalog panellerinde arka plan çizdirmek YASAK (T3 kullanılır).
> Mekân değişmedikçe ikinci bir T1 üretilmez.

### 3.5.2 T1 (kuruluş) panelleri için katı kurallar
AI'ı en çok ele veren üretimler bunlar; o yüzden en sıkı kurallar burada:

- **Okunabilir yazı/tabela YASAK:** `no readable signs, no text, no logos; any signage abstract or blurred`. (Bozuk yazılı tabela = anında AI görünümü.)
- **Yoğun tekrar eden geometri YASAK:** cam gökdelen cephesi, uzayıp giden pencere ızgarası, araba dolu cadde, kalabalık kavşak çizdirilmez.
- **Sığ kadraj:** sokak boyunca derinlemesine bakış yerine duvara/vitrine paralel, karakterin hemen arkasını gösteren sığ açılar tercih edilir. Derinlik gerekiyorsa gece + bokeh ışıklarla verilir.
- **Mekânı basitleştir:** bir mekân en fazla 3-4 tanımlayıcı öğeyle tarif edilir (ör. "ahşap bar tezgâhı, arka rafta şişeler, sıcak sarkıt lambalar") — "detaylı, gerçekçi sokak" gibi genel tarifler yasak.
- Kalabalık gerekiyorsa: `background people as simple muted silhouettes, out of focus`.

### 3.5.3 Mekân referans sheet'leri
Tekrarlayan mekânlar (FL'nin odası, okul, kafe...) karakterler gibi ele alınır:
- Seri başında her tekrarlayan mekân için **1 adet boş mekân görseli** üretilir (T1 kalitesinde, karaktersiz), beğenilene kadar iterasyon yapılır, sonra dondurulur.
- O mekândaki her T1/T2 panelinde bu sheet referans görsel olarak verilir → mekân da karakterler gibi bölümler arası tutarlı kalır.
- Dosya düzeni: `locations/ODA_ref.png, KAFE_ref.png ...`

### 3.5.4 Kod tarafı sigorta
- T2 panelleri için garanti yöntem: modelden nispeten net üretilen arka planı **kodla blur'lamak** (karakter maskesi + gaussian blur). Model blur'u tutarsız yaparsa bu devreye girer.
- Tüm panellere birleştirme aşamasında hafif ortak renk düzeltmesi (doygunluk kısma + aynı ton eğrisi) uygulanabilir — paneller arası "farklı üretim" hissini azaltır.

---

## 4. PANEL PROMPT ŞABLONU

Her panel üretimi bu şablonla yapılır:

```
{STYLE BLOCK}
{SCENE BLOCK [Sx]}
{Panelde görünen karakterlerin KİMLİK BLOKLARI}

PANEL:
SHOT: <kamera açısı — Bölüm 5.2 listesinden>
BG TIER: <T1 / T2 / T3 — Bölüm 3.5; T2 ise "background heavily blurred, only
  soft color shapes", T3 ise "plain soft <renk> background, no environment">
ACTION: <tek cümlede ne oluyor + ifadeler>
FOCUS: <neye odaklanıyoruz>
BUBBLE SPACE: leave empty negative space at <top/upper-left/right>
  for speech bubbles, roughly <%20-30> of the frame
NO TEXT, no speech bubbles, no letters anywhere in the image.
```

(Balonları modelin çizdiği deneysel yöntemde son satır Bölüm 7.B ile değişir.)

---

## 5. PANEL VE KOMPOZİSYON KURALLARI

### 5.1 Panel boyutları
- Şerit genişliği: **690 px** (tam genişlik panel = 690 px genişliğinde üretilir/ölçeklenir).
- Üretim oranları — üç standart yeterli:
  - **Portre panel** (2:3 ~ 3:4 dikey): diyalog, tek karakter, duygu. En sık kullanılan.
  - **Kare panel** (1:1): ikili konuşma, obje insert.
  - **Geniş panel** (16:9 ~ 3:2 yatay): mekân kuruluşu, kalabalık.
- Dar panel (bant şeklinde ekstrem yakın plan) = geniş üretilir, kodla kırpılır.

### 5.2 Kamera çeşitliliği (ZORUNLU rotasyon)
Referans eserin canlılığı buradan geliyor. Kurallar:
- **Aynı açı üst üste iki panelde tekrarlanamaz.**
- Her sahnede en az bir kez: geniş kuruluş planı, bir yakın plan, bir insert.
- Kullanılacak açı havuzu: geniş plan / bel plan / omuz üstü / yakın yüz / **ekstrem yakın** (sadece gözler, sadece eller, sadece ayaklar) / **obje insert** (bardak, telefon, devrilen kutu...) / arkadan siluet / yüksek açı.
- Duygusal doruk = tam genişlik panel + öncesinde/sonrasında bol boşluk.

### 5.3 Balon boşluğu
Paneller **yazı sonradan eklenecekmiş gibi** kurgulanır: her diyalog panelinde kadrajın üst veya yan %20-30'u sade/boş bırakılır (BUBBLE SPACE satırı zorunlu). Karakterin kafası kadrajın merkez-altına yerleştirilir ki üstte balon yeri kalsın.

### 5.4 Gag register'ı (chibi/karalama modu)
Referans eserde mizah, stil değişimiyle veriliyor. Kural:
- Bölüm başına 1-3 kez, **komik iç ses / abartılı tepki** anlarında panel bilerek basit karalama/chibi stiline döner.
- Bu paneller için STYLE BLOCK yerine **GAG STYLE BLOCK** kullanılır:
```
GAG STYLE BLOCK:
Crude doodle style, thick simple lines, flat colors or plain white background,
chibi/simplified version of the character (keep hair color and cut recognizable),
comedic, sketchy, like a quick funny doodle inside a webtoon.
```
- Karakterin saç rengi/kesimi chibi'de bile korunur (tanınırlık).
- Gag panelleri küçük boyutlu yerleştirilir (tam genişlik yapılmaz).

---

## 6. ŞERİT BİRLEŞTİRME KURALLARI (kod tarafı)

- Çıktı: 690 px genişlik, dikey akış; ~4000 px'lik dilimlere bölünerek servis edilir.
- **Boşluk = tempo.** Panel arası dikey boşluklar:
  - Normal akış: 80-150 px beyaz
  - Sahne geçişi: 300-500 px beyaz
  - Dramatik duraklama / vurgu: 500-800 px (referans eserde bolca var)
- **Zemin rengi anlam taşır:** beyaz = normal; **siyah** = iç monolog, geçmiş, karanlık an (sahne bloğunda işaretlenir); tam kanamalı renk = rüya/duygusal doruk (panel kenar boşluksuz, 690 px tam genişlik).
- Panel hizalama: hepsi ortalanmış olmak zorunda değil — küçük paneller sola/sağa yaslanarak ritim yaratılır (referans eserde sık kullanılıyor).
- Bölüm sonu: son panelden sonra uzun boşluk + "DEVAM EDECEK" tipografisi (kod ile basılır).

---

## 7. BALON VE METİN KURALLARI

### 7.A Varsayılan yöntem: KOD OVERLAY (üretimde bu kullanılır)
Model **metinsiz ve balonsuz** panel üretir; balon + yazı kodla basılır.

Balon tipleri (referans eserdeki dil):
| Tip | Görünüm | Kullanım |
|---|---|---|
| Konuşma | Beyaz elips, ince siyah kontur, kuyruk konuşana | Normal diyalog |
| Anlatıcı | Köşeli altıgen/dikdörtgen kutu, açık gri zemin | Dış ses, zaman/mekân bilgisi |
| İç ses | Kuyruksuz yuvarlak balon veya düşünce baloncukları | Düşünce |
| Fısıltı / kadraj dışı | Kesikli (dashed) konturlu balon | Alçak ses, panel dışından gelen ses |
| Sıkıntı/mırıltı | Renkli (pembe) tırtıklı balon | Utanma, iç geçirme |
| Bağırma/vurgu | Balon çevresine ışınsal odak çizgileri | Şok, yüksek ses |
| Mesajlaşma | Chat arayüzü taklidi (sarı/beyaz baloncuklar, avatar) | Telefon yazışması |

Tipografi: köşeli, tamamı BÜYÜK HARF, webtoon fontu (ör. CC Wild Words tarzı / Komika benzeri Türkçe karakter destekli bir font). Satırlar kısa kırılır (balon başına en fazla ~3 kısa satır). Bir panelde en fazla 2-3 balon.

### 7.B Deneysel yöntem: MODEL BALONU DA ÇİZER (karşılaştırma örneği için)
- Prompt'a eklenir: `Include speech bubble(s) with the following TURKISH text, ALL CAPS, exactly as written: "..."`
- Türkçe karakter riski (İ, ğ, ş, ç, ö, ü) yüksektir → üretim sonrası metin birebir kontrol edilir; tek harf hatası = yeniden üretim.
- Bu yöntem yalnızca kıyas/örnek amaçlıdır; seri üretimde 7.A kullanılır.

### 7.C Ses efektleri (SFX)
- Büyük, elle çizilmiş görünümlü, hafif eğik tipografi; panelin üzerine taşabilir.
- Kod overlay ile basılır (öneri: 6-10 hazır SFX PNG/font seti: PAT!, GÜM!, ŞAK!, VINN, TIK TIK, GULP...).
- Kural: SFX panel başına en fazla 1, sadece gerçekten ses olan anlarda.

---

## 8. HİKÂYE VE DİYALOG KURALLARI

Amaç: konular derin olmasa da **okutan** konuşmalar. Referans eserin yaptığı gibi:

### 8.1 Bölüm iskeleti (60-90 panel / bölüm)
1. **Soğuk açılış (ilk 3-5 panel):** bölümün en çarpıcı anından bir kesit veya iddialı bir iç ses cümlesiyle başla; sonra "X saat önce" akışına dön. (Referans eser tam olarak böyle açılıyor.)
2. **Kurulum:** karakterin günlük hali + karakteri sevdiren küçük detaylar (mizah burada).
3. **Kıvılcım:** bölümün ana karşılaşması/çatışması.
4. **Yükseliş:** diyalog ping-pong'u, yanlış anlaşılma, gerilim.
5. **Cliffhanger:** bölüm HER ZAMAN cevabı bir sonraki bölümde olan bir soru/an ile biter (yarım kalan cümle, beklenmedik temas, kapıda görünen kişi).

### 8.2 Diyalog yazım kuralları
- **Kısa vuruşlar:** balon başına en fazla ~12 kelime. Uzun açıklama = anlatıcı kutusuna veya ikiye böl.
- **İç ses ↔ dış ses zıtlığı:** karakterin söylediği ile düşündüğünün çelişmesi en ucuz ve en etkili mizah/gerilim aracı. Bölüm başına en az 3 kez kullan.
- **Ping-pong:** diyaloglar soru-cevap-ters köşe ritminde; kimse podcast konuşması yapmaz, herkes tepki verir.
- **Her sahnenin bir isteği var:** sahnedeki karakterlerden en az biri o sahnede bir şey istiyor olmalı (numara almak, kaçmak, kanıtlamak...). İstek yoksa sahne silinir.
- **Alt metin:** karakterler istediklerini doğrudan söylemez; laf çevirir, bahane üretir. ("Eve gitmek istememe sebebim—" "Soğuk.")
- **Mizah dozu:** her 10-15 panelde bir gülümseten an (gag paneli, iç ses, absürt karşılaştırma).
- **Tekrar eden şaka/motif:** seri başına 1-2 running gag (referans eserde: FL'nin sosyal ortamlardan kaçma bahaneleri).
- Küfür/argo yok; iğneleyici zekâ var.

### 8.3 İsimlendirme
- Karakter isimleri hedef kitleye göre seçilir ve `topics/karakter dosyasında` sabitlenir; bölümler arası asla değişmez.

---

## 9. DOSYA VE ADLANDIRMA DÜZENİ

```
/seri-adi/
  characters/
    MIRA_turnaround.png, MIRA_expressions.png, MIRA_outfits.png
    characters.json        ← kimlik blokları + sheet dosya yolları
  locations/
    ODA_ref.png, KAFE_ref.png ...   ← tekrarlayan mekân referansları
  bolum-01/
    script.json            ← sahneler → paneller → balon metinleri
    panels/ S01_P001.png ...
    strip/  bolum-01_001.webp ... (690xN dilimler)
```

`script.json` panel kaydı asgari alanları:
`{scene, panel, shot, action, chars[], bubbles[{type, char, text}], size, gag:bool, bg:"white|black|bleed"}`

---

## 10. KALİTE KONTROL CHECKLİST (her panel için)

- [ ] Yüz, saç kesimi/rengi ve imza detay sheet ile eşleşiyor mu?
- [ ] Kıyafet sahne kilidiyle aynı mı?
- [ ] Palet sahne kilidine uyuyor mu (doygunluk kaçmış mı)?
- [ ] Çizgi kalınlığı önceki panellerle uyumlu mu?
- [ ] Balon için boşluk bırakılmış mı?
- [ ] Görselde istenmeyen yazı/harf/logo var mı? (varsa yeniden üret)
- [ ] Arka plan kademesi plana uygun mu? (T3 panelinde mekân çizilmişse yeniden üret)
- [ ] T1 panelinde bozuk tabela, tekrar eden pencere ızgarası, garip perspektif var mı?
- [ ] Arka plan karakterden daha detaylı/daha net mi? (ise blur uygula veya yeniden üret)
- [ ] El/parmak, göz hizası gibi klasik AI hataları var mı?
- [ ] Kamera açısı önceki panelin tekrarı mı? (ise yeniden planla)

Bölüm için:
- [ ] Soğuk açılış çarpıcı mı? Cliffhanger gerçek bir soru bırakıyor mu?
- [ ] Gag paneli sayısı 1-3 arasında mı?
- [ ] Şerit temposu: dramatik anlarda boşluk kullanılmış mı?

---

## 11. BİLİNEN RİSKLER

- **Tutarlılık zamanla kayar:** her panel yalnızca sheet'e + bir önceki panele referanslanır; asla "bir önceki panelin çıktısını tek referans" yapıp zinciri uzatma (fotokopi etkisiyle stil sürüklenir). Sheet her zaman birincil referanstır.
- **Türkçe metin görsel içinde güvenilmez** → seri üretimde daima overlay.
- **Uzun dikey görsel üretimi güvenilmez** → model asla tam dilim üretmez.
- **Kalabalık sahneler** en riskli üretimlerdir → figüranları basitleştir, ana karakterleri önde ve büyük tut.
- **Detaylı mekân panelleri (T1) en "AI görünümlü" üretimlerdir** → sayıları sahne başına 1-2 ile sınırlıdır, tabela/yazı yasağı ve basitleştirme kuralları (3.5.2) pazarlıksız uygulanır. Şüphede kalınca T2/T3'e düş.
