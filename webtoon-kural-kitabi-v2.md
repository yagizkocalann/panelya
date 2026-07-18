# WEBTOON ÜRETİM KURAL KİTABI
### AI Webtoon Pipeline — Görsel Tutarlılık ve Hikâye Anayasası (v2 birleşik aday)

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
Backgrounds: clearly hand-drawn digital manhwa environments built from clean,
economical lineart and simplified architectural shapes. Keep correct perspective
and recognizable place details, but reduce texture into a few intentional marks
and two or three matte watercolor-gradient value groups. Distant detail becomes
lighter and is omitted rather than blurred; characters stay the sharpest layer.
No photographic texture, no photobash look, no lens blur, no depth-of-field,
no glossy wet-surface rendering, and no cinematic color grading. Ordinary panels
have no bloom. A restrained soft rim glow is allowed only in explicitly marked
emotional B panels. Overall mood: airy, romantic, illustrated, weekly-webtoon clean.
```

**Yasaklılar listesi** (negatif talimat olarak da eklenebilir):
anime screentone, 3D render, photorealism, photobash, photographic texture, lens blur, depth-of-field, bokeh, glossy architecture, mirror-like wet streets, cinematic color grading, excessive bloom, chibi (gag panelleri hariç — Bölüm 5.4), kalın dış kontur, aşırı doygun renk, batı çizgi roman gölgelemesi, metin/yazı (overlay yönteminde).

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
ARKA PLAN ÇİZGİ KİLİDİ: <ana kaçış noktası + korunacak 3 mimari işaret + sadeleştirilecek doku>
```

Palet kilidi örnekleri (referans eserden):
- Ev/oda + samimi an → sıcak pembe/krem/şeftali
- Bar/gece içmece → soğuk mavi-gri + sıcak nokta ışık
- Gece sokağı/gerilim → koyu teal, lacivert, neon lekeler
- Rüya/hayal → parlak camgöbeği, yüksek parlaklık; glow yalnız odak çevresinde seçici ve düşük yoğunlukta

---

## 3.5 ARKA PLAN SİSTEMİ (AI görünümünü öldüren bölüm)

AI arka planlarının yapay durmasının ana sebepleri her panelde aynı ayrıntı seviyesini istemek, fotoğraf dokusunu taklit etmek ve derinliği blur/bokeh ile kurmaktır. Webtoon üretiminde mekân sahne başına 1-2 panelde kurulur; sonraki panellerde çizgi ve bilgi bilinçli olarak azaltılır.

### 3.5.1 Yoğunluk kademesi + panel register'ı

Üç yoğunluk kademesi korunur; üretim ve QA için dört işlevsel register'a bağlanır:

| Register | Kademe | İçerik | Sahnedeki hedef oran |
|---|---|---|---|
| **E — Establishing** | **T1 — Kuruluş** | Mekân geometrisi ve 3-5 ayırt edici işaret okunur. Perspektif doğru; yüzeyler çizgisel, mat ve sade kalır. Sahne başına en fazla 1-2 panel. | ~%10 |
| **N — Normal** | **T2 — İma** | Karakter oyunculuğunun arkasında yalnız 1-3 mekân işareti, geniş açık renk blokları ve birkaç ince kontur kalır. Uzak ayrıntı blur ile değil çizgiyi eksilterek azaltılır. | %20-30 |
| **B — Beat** | **T3 — Soyut/Boş** | Duygusal vurgu: sade gradyan, tek mekân motifi veya seyrek çizgi. Yalnız odak çevresinde çok düşük yoğunluklu rim glow kullanılabilir. | %40-50 |
| **C — Comedy** | **T3 — Soyut/Boş** | Düz renk, sembolik çizgi veya doodle zemin. Gerçekçi mekân render'ı kullanılmaz. | Bölümde 1-3 panel |

> Kural: Yeni bir mekân E ile kurulur; akış N/B/C'ye geçer. Mekân ve kamera ekseni değişmedikçe ikinci bir E kullanılmaz. Yakın plan ve diyalog panelleri varsayılan olarak N veya B'dir.

### 3.5.2 E/T1 kuruluş panelleri için katı kurallar

- **Okunabilir yazı/tabela YASAK:** `no readable signs, no text, no logos; signage reduced to blank geometric shapes`.
- **Yoğun tekrar eden geometri YASAK:** uzayıp giden pencere ızgarası, araba dolu cadde ve kalabalık kavşak çizdirilmez.
- **Mekânı basitleştir:** bir mekân en fazla 3-5 tanımlayıcı öğeyle tarif edilir; "detaylı, gerçekçi sokak" gibi açık uçlu tarifler kullanılmaz.
- **Perspektif sade ama doğrudur:** sığ kadraj tercih edilebilir; hikâye derin kadraj gerektiriyorsa kaçış çizgileri korunur fakat uzak cepheler kontur silueti ve düz değer bloklarına iner. Derinlik bokeh veya lens blur ile verilmez.
- **Yüzey ekonomisi:** tek tek taş, tuğla, sıva ve ahşap render edilmez. Doku yalnız birleşim/köşelerde toplam 15-25 kısa işaretle sınırlanır.
- Kalabalık gerekiyorsa: `background people simplified, low detail, muted silhouettes`.

### 3.5.3 N/T2 ima panelleri için katı kurallar

- Arka plan 1-3 mekân işaretinden fazlasını taşımaz: örneğin tek kemer eğrisi, bir aplik ve geniş duvar bloğu.
- Uzaklık, Gaussian blur veya depth-of-field ile değil; daha açık değer, daha ince kontur ve çizgiyi tamamen atlama ile kurulur.
- Karakterin siluetine değen mimari çizgiler azaltılır; yüz ve beden konturu en keskin katmandır.
- Bokeh, ışık noktası ve fotoğraf lensi dili yalnız özel anlatı gerekçesi varsa ayrı deney olarak denenir; varsayılan üretim standardı değildir.

### 3.5.4 B/T3 ve C/T3 kuralları

- B panelinde arka plan; mat gradyan, tek ince motif veya duygu dokusudur. Tüm kadraflı bloom yasaktır.
- Glow gerekiyorsa yalnız yüz, el veya anahtar gibi tek odakta düşük yoğunluklu rim light olarak kullanılır.
- C paneli düz zemin ve birkaç gag çizgisiyle sınırlıdır; mekân ayrıntısı çizilmez.
- Siyah/beyaz/tam kanamalı renk seçimi Bölüm 6'daki anlatı anlamıyla uyumlu olmalıdır.

### 3.5.5 Yağmur ve ıslak zemin kuralı

- Yağmur ince çizgiler ve birkaç mat, kırık değer lekesiyle anlatılır.
- Islak zeminde yalnız 2-4 kısa, yumuşak yansıma şekli kullanılır.
- Ayna gibi karakter yansıması, neon parlaması, lens flare ve yüksek kontrastlı parlak asfalt yasaktır.

### 3.5.6 Mekân referans sheet'leri

Tekrarlayan mekânlar karakterler gibi ele alınır:

- Seri başında her tekrarlayan mekân için bir adet karaktersiz E/T1 referans sheet'i üretilir, onaylanır ve dondurulur.
- Sheet; ana kaçış noktası, kapı/pencere/merdiven konumu, 3-5 imza öğe ve sahne paletini kilitler.
- Aynı mekândaki E ve N panellerinde bu sheet birincil geometri referansıdır. Bir önceki panel tek başına referans yapılmaz.
- Dosya düzeni: `locations/ODA_ref.png, KAFE_ref.png ...`

### 3.5.7 Kod tarafı sigorta

- Varsayılan üretimde karakter maskesi + Gaussian blur uygulanmaz; kenar halosu ve fotoğrafik depth-of-field hissi oluşturabilir.
- Gerekirse arka plan ayrı katmanda doygunluk/değer açısından hafifçe geri çekilir; geometri ve çizgi karakteri korunur.
- Tüm panellere hafif ortak renk düzeltmesi uygulanabilir; bu işlem yerel paleti ezmemeli ve bloom eklememelidir.

---

## 4. PANEL PROMPT ŞABLONU

Her panel üretimi bu şablonla yapılır:

```
{STYLE BLOCK}
{SCENE BLOCK [Sx]}
{Panelde görünen karakterlerin KİMLİK BLOKLARI}

PANEL:
SHOT: <kamera açısı — Bölüm 5.2 listesinden>
BACKGROUND REGISTER: <E / N / B / C — Bölüm 3.5>
BG TIER: <T1 / T2 / T3 — register ile eşleşen yoğunluk>
BACKGROUND LOCK: <korunacak 1-5 mekân işareti + sadeleştirme seviyesi>
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
`{scene, panel, shot, action, chars[], bubbles[{type, char, text}], size, register:"E|N|B|C", bgTier:"T1|T2|T3", gag:bool, bg:"white|black|bleed"}`

---

## 10. KALİTE KONTROL CHECKLİST (her panel için)

- [ ] Yüz, saç kesimi/rengi ve imza detay sheet ile eşleşiyor mu?
- [ ] Kıyafet sahne kilidiyle aynı mı?
- [ ] Palet sahne kilidine uyuyor mu (doygunluk kaçmış mı)?
- [ ] Çizgi kalınlığı önceki panellerle uyumlu mu?
- [ ] Balon için boşluk bırakılmış mı?
- [ ] Görselde istenmeyen yazı/harf/logo var mı? (varsa yeniden üret)
- [ ] Arka plan register'ı ve kademesi plana uygun mu? (B/C panelinde gereksiz mekân çizilmişse yeniden üret)
- [ ] T1 panelinde bozuk tabela, tekrar eden pencere ızgarası, garip perspektif var mı?
- [ ] Arka plan karakterden daha detaylı/daha net mi? (ise çizgiyi/dokuyu azaltarak yeniden üret; blur varsayılan çözüm değildir)
- [ ] Mekân çizgiyle kurulmuş mu; fotoğraf dokusu, lens blur veya parlak 3D yüzey hissi var mı? (varsa yeniden üret)
- [ ] Yağmur/ıslak zemin varsa yansımalar mat ve 2-4 kısa lekeyle sınırlı mı?
- [ ] Glow yalnız işaretli B panelinde ve tek odak çevresinde mi?
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
- **Detaylı mekân panelleri (E/T1) en "AI görünümlü" üretimlerdir** → sayıları sahne başına 1-2 ile sınırlıdır, tabela/yazı yasağı ve basitleştirme kuralları (3.5.2) pazarlıksız uygulanır. Şüphede kalınca N/T2 veya B/T3'e düş; blur ekleme.
