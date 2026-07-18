# Panelya temiz dijital romantik webtoon üretim kural kitabı

Durum: v1.0 / üretim kapısı
Tarih: 18 Temmuz 2026
Sahipler: Producer, Story, Art Director
Uygulama alanı: özgün romantik drama, romantik komedi ve modern hayat webtoonları

## 1. Amaç ve sınır

Bu kitap, Kore dijital romantik webtoonlarında görülen profesyonel ve insan eliyle yönetilmiş üretim hissini Panelya'nın tamamen özgün hikâyelerinde tekrar edilebilir hale getirir. Hedef belirli bir eseri, sanatçıyı, karakteri veya panel dizisini kopyalamak değildir. Hedef; temiz çizgi ekonomisi, kontrollü render, mobil ritim, karakter oyunculuğu ve anlatı-lettering bütünlüğünden oluşan genel üretim grameridir.

Kesin sınırlar:

- Referans eserin yüzleri, saç siluetleri, kıyafetleri, mekânı, nesne motifi, diyalogları ve olay sırası yeniden üretilmez.
- Referans kareler üretim modeline girdi olarak verilmez ve repoya alınmaz.
- Üretilecek her karakter, mekân, çatışma, motif ve metin özgün olur.
- “Aynısını yap” kabul edilmez; “aynı profesyonel üretim disiplini ve okunabilirlik” kabul edilir.
- GPT Image ham üretici olabilir; nihai sanat yönetimi, seçim, kompozit, lettering ve QA ayrı aşamalardır.

## 2. İnceleme tabanı

Bu sürüm, kullanıcının yerel İndirilenler klasöründe tuttuğu ilk 10 dikey bölüm parçasının görsel incelenmesine dayanır. Dosyalar yalnızca yerinde görüntülendi; kopyalanmadı ve repoya alınmadı.

Gözlenen işlevler:

| Parça | Ana işlev | Çıkarılan genel ilke |
| --- | --- | --- |
| 001 | Kapak/kolaj | Seri vaadi tek bir illüstrasyon değil, farklı duygu yakınlıklarının montajıyla verilebilir. |
| 002 | Provokatif cold open | İlk ekranlarda açıklamadan önce ilişki sorusu ve güçlü beden oyunculuğu kullanılabilir. |
| 003 | Nesne darbesi ve tepki | Fiziksel olay, büyük SFX ve sade reaksiyon paneliyle ritmi bir anda kırar. |
| 004 | Geri sarma ve nesne kurulum | Anlatıcı kutusu, geniş boşluk ve nesne insert'i zaman geçişini ucuz ve açık kurar. |
| 005 | Meet-cute mikro hareketleri | El, bakış, omuz ve boy farkı romantik gerilimi diyalogdan önce taşır. |
| 006 | Sosyal yanlış anlama | Diyalog, iç ses ve chibi komedi aynı sahnede farklı grafik dillerle ayrılır. |
| 007 | Nesneden temaya geçiş | Tekrarlanan nesne, göz yakın planı ve çevresel metafor arasında görsel köprü kurar. |
| 008 | İdealize fantezi/sıçrama | Kısa süreli yüksek detaylı atmosfer paneli bölümün duygusal vaadini büyütür. |
| 009 | Başlık ve ana zaman çizgisi | Cold open sonrasında başlık kartı, mekân kurucu plan ve yeni renk zemini kullanılır. |
| 010 | Gündelik karakterizasyon | Oda eşyası, telefon mesajı, kıyafet ve küçük sosyal konuşma karakteri doğrudan anlatır. |

İlk 10 parça bütün bölümün panel sayısını veya final yapısını temsil etmez. Bu nedenle v1 sayısal hedefleri referans bölümün birebir istatistiği değil, Panelya üretim standardıdır.

## 3. “AI görseli” hissinin teşhisi

Mevcut `master-refined.png` teknik olarak temiz fakat hedef gramerden uzaktır. Sorun düşük kalite değil, yanlış kalite türüdür.

### 3.1 Mevcut pilotta AI hissi yaratan özellikler

1. Her panel aynı yüksek render seviyesinde. İnsan yapımı haftalık webtoon, önemsiz planlarla duygusal zirvelere eşit emek vermez.
2. Her yüz “güzel illüstrasyon” için poz veriyor. Referans gramerinde yüzler konuşma ortasında, eksik, komik veya nötr kalabilir.
3. Arka planlar sürekli sinematik ve ayrıntılı. Profesyonel dikey bölüm arka plan yoğunluğunu beat'e göre açıp kapatır.
4. Işık global ve fotoğrafik. Hedefte çoğu panel düz yerel renk + tek gölge kademesidir; parıltı yalnız vurgu anında gelir.
5. Kontur ve yüzey dokusu aynı anda çok zengin. Bu, çizgi roman panelinden çok konsept illüstrasyon hissi verir.
6. Paneller tek üretimde birbirine “poster sayfası” gibi bağlanır. Gerçek bölümde panel, balon ve boşluk ayrı ritim birimleridir.
7. Karakterlerin ifade aralığı dar; güzellik korunurken oyunculuk kaybolur.
8. Hata ve asimetri dili yok. İnsan eli hissi anatomik hata demek değildir; seçici çizgi, küçük açı farkı ve ekonomik bitiriş demektir.
9. Metin için kompozisyon boşluğu sonradan düşünülmüş görünür. Hedefte balonlar thumbnail aşamasından itibaren kadrajın parçasıdır.
10. Aynı render modu komedi, gündelik konuşma, romantik bakış ve kurucu planın tamamında kullanılır.

### 3.2 Yeni temel ilke

“Daha ayrıntılı” yerine “daha seçici” üretim yapılır. Kalite; piksel başına detay değil, doğru beat'te doğru çizim moduna geçebilme becerisidir.

## 4. Stil DNA'sı

### 4.1 Ana tanım

Temiz modern dijital romantik webtoon; ince ve kararlı koyu gri kontur, düz yerel renk, bir ana cel gölge, seçici yumuşak atmosfer, idealize fakat okunaklı yetişkin oranları, güçlü göz oyunculuğu, bol negatif alan ve kontrollü komedi deformasyonu.

### 4.2 Çizim modları

Her bölüm tek render moduyla çizilmez. Aşağıdaki dört mod storyboard üzerinde etiketlenir.

| Kod | Mod | Kullanım | Bölüm hedefi |
| --- | --- | --- | --- |
| N | Normal anlatı | Diyalog, hareket, gündelik yaşam | %55-65 |
| C | Komedi/chibi | Yanlış anlama, sosyal gerilim tahliyesi, kısa reaksiyon | %12-20 |
| B | Beauty/duygusal vurgu | Bakış, romantik fark ediş, kırılma, arzu | %10-15 |
| E | Establishing/atmosfer | Mekân, zaman, hava, sınıfsal veya sosyal bağlam | %8-12 |

Arka arkaya üçten fazla B modu kullanılmaz. C modu gerçek duygusal sonucu iptal etmez; yalnız basıncı boşaltır.

### 4.3 Kontur

- Çalışma master'ı 1600 px genişlikte hazırlanır.
- N modu dış siluet: yaklaşık 4-7 px; yüz içi ve kıyafet iç çizgileri: 2-4 px.
- B modu kirpik ve göz üst çizgisi 5-8 px'e çıkabilir; burun ve dudak çizgisi 1.5-3 px kalır.
- C modu 5-9 px daha grafik ve yuvarlak kontur kullanabilir.
- Kontur ana rengi saf siyah değil, çoğu sahnede `#263038` veya sahneye uyarlanmış çok koyu lacivert/gri olur.
- Saç kütlesi dıştan net; iç teller az ve yönlüdür. Her saç teli çizilmez.
- Giysi kıvrımı anatomik çekme noktalarından çıkar: omuz, dirsek, bel, diz. Rastgele çoklu kırışıklık yasaktır.
- Çizgi her yüzeyde aynı yoğunlukta olmaz. Odak dışı nesne çizgisi daha açık ve azdır.

### 4.4 Renk ve gölge

- Yerel renkler önce düz blok olarak kurulur.
- N modunda bir ana cel gölge yeterlidir. İkinci kademe yalnız yüz, saç veya önemli kumaşta kullanılabilir.
- Ten gölgesi gri-kahve değil, düşük doygunluklu pembe-mor veya sıcak şeftali ailesinde kalır.
- Allık burun üstü ve göz altına çok düşük opaklıkta uygulanır; her panelde kullanılmaz.
- Saf beyaz yalnız göz parlaması, ekran, vurgu ve boşluk için saklanır.
- Arka plan doygunluğu karakterden çoğunlukla %10-25 daha düşüktür.
- B modunda yumuşak gradient, bokeh veya saç kenar ışığı açılabilir; N moduna taşınmaz.
- E modunda tek baskın mevsim/ortam rengi kullanılabilir: bahar pembesi, deniz turkuazı, gece laciverti gibi.
- Gürültü, kâğıt dokusu ve fırça izi bütün resme eşit uygulanmaz. Doku yalnız atmosfer veya materyal işlevi gördüğünde eklenir.

### 4.5 Yüz grameri

- Yüz formu idealize edilir fakat her karaktere ayrı çene, göz aralığı, kaş açısı ve burun uzunluğu verilir.
- Gözler büyük olabilir; iki göz hiçbir zaman kopyala-yapıştır simetrisi taşımaz.
- Üst kirpik baskın, alt kirpik seçicidir. Alt göz çizgisi tam halka olmaz.
- Burun çoğu N panelinde kısa köprü veya burun ucu işaretiyle çözülür.
- Ağız, duyguya göre 1-3 kararlı çizgidir. Sürekli parlak tam dudak render'ı kullanılmaz.
- Nötr yüz meşrudur. Her panelde dramatik kaş, yoğun allık veya açık ağız aranmaz.
- Bakış yönü, baş açısı ve omuz yönü aynı duyguyu tekrar etmez; küçük karşıtlık oyunculuk yaratır.
- B modu yakın planda göz irisi ayrıntısı artabilir, ancak diğer yüz ayrıntıları sadeleşir.

### 4.6 Beden ve el

- Yetişkin oranları korunur; baş-boy oranı karaktere göre sabitlenir.
- Boy farkı her iki karakterin model sheet'inde santimetre ve “baş” birimiyle tanımlanır.
- Omuz, göğüs kafesi ve pelvis üç ayrı hacim olarak düşünülür; karakterler lastik gövdeli olmaz.
- Eller romantik mikro-oyunculuğun ana aracıdır. Her el panelinde parmak sayısı, başparmak yönü, eklem ve tutulan nesne teması kontrol edilir.
- El yakın planı üretimden önce kaba 3D/poz referansı veya gerçek el fotoğrafıyla doğrulanır; referans telifli panel olmaz.
- Erotik vurgu amaçlanmıyorsa kamera göğüs, kalça veya kası sebepsiz büyütmez.

### 4.7 Saç ve kıyafet

- Her karakter için önden, 3/4, profilden ve arkadan saç silueti kilitlenir.
- Saç bir ana kütle + 3-7 karakteristik tutam olarak tanımlanır.
- Parlaklık tek büyük şekil veya birkaç kontrollü kırık şerittir; fotoğrafik tel tel parlama kullanılmaz.
- Kıyafet bölüm içinde model sheet'e bağlıdır: yaka, düğme, dikiş, kol boyu, aksesuar ve renk kodları kayda alınır.
- Figüranın kıyafeti ana karakterden daha düşük kontrast ve ayrıntı taşır.

### 4.8 Arka plan

Üç yoğunluk seviyesi vardır:

- BG-3 / kurucu: mimari, perspektif, tabela mantığı ve mekân ilişkisi okunur.
- BG-2 / diyalog: ana raf, pencere, masa, kapı gibi 2-4 bağlam işareti yeterlidir.
- BG-1 / duygu: düz renk, gradient, hız çizgisi, çiçek, ışık veya boşluk.

Bir sahnede önce en az bir BG-3 gerekir; sonra BG-2 ve BG-1'e geçilebilir. 3D veya foto tabanlı yardımcılar kullanılırsa perspektif korunur, ayrıntı sadeleştirilir, kontur/renk karakter sanatıyla birleştirilir. Lisanssız fotoğraf veya başkasının panel arka planı kullanılmaz.

## 5. Dikey panel ve boşluk grameri

### 5.1 Tuval

- Çalışma genişliği: 1600 px.
- Yayın türevi: 800 px genişlik.
- Panel sanatı, balon ve SFX ayrı katman gruplarında tutulur.
- Uzun bölüm çalışma dosyası mantıksal sekanslara ayrılır; tek dev yapay zekâ görseli üretilmez.
- Export, platform/uygulama sınırına göre dikey dilimlenir. WEBTOON CANVAS güncel otomatik optimizasyonu 800 x 1280 px azami dilimler üzerinden açıklar; Panelya kendi manifestinde daha uzun WebP/AVIF varlıkları destekleyebilir ancak mobil decode maliyeti ayrıca ölçülür.

### 5.2 Ekran birimi

Storyboard, yalnız panel sayısıyla değil “mobil ekran” birimiyle değerlendirilir. 800 x 1280-1500 px yaklaşık bir okuma ekranı kabul edilir.

- Bir ekranda tek B modu yakın plan güçlüdür.
- Bir ekranda en fazla 2 orta boy N panel veya 3 küçük C/insert panel önerilir.
- Önemli cümle ve önemli yüz aynı ekranın iki uzak ucuna atılmaz.
- Reveal, okuyucunun kaydırmasıyla tamamlanmalıdır; üst kısmı görünürken sonuç henüz görünmemelidir.

### 5.3 Boşluk sınıfları

| Sınıf | 1600 px master karşılığı | İşlev |
| --- | ---: | --- |
| G0 | 40-100 px | Aynı hareketin devamı |
| G1 | 120-240 px | Normal panel geçişi |
| G2 | 280-520 px | Cümle sonrası bekleme, küçük gerilim |
| G3 | 560-900 px | Zaman atlaması, utanç, fark ediş |
| G4 | 1000-1800 px | Büyük reveal, başlık, sahne/duygu kırılması |

Boşluk dekor değildir. Her G2-G4 storyboard'da `pause`, `time`, `reveal`, `distance` veya `silence` etiketi taşır.

### 5.4 Zemin semantiği

- Beyaz zemin: gündelik zaman, açıklık, romantik hafiflik, sosyal komedi.
- Siyah zemin: içe kapanma, zaman sıkıştırma, yalnızlık, anlatıcı mesafesi, ciddi geçiş.
- Sahne renkli zemini: kısa komedi, mesajlaşma veya tek duygunun grafik vurgusu.
- Beyazdan siyaha geçiş, anlatıcı veya duygu değişimi olmadan yapılmaz.

### 5.5 Panel sınırı

- Normal sahnede ince dikdörtgen sınır veya sınırsız karakter kesiti.
- Hareket panelinde eğik kenar veya sınır aşan SFX kullanılabilir.
- B modu görseli tam genişlik ve sınırsız olabilir.
- C modu küçük, yüzen ve düzensiz şekilli olabilir.
- Aynı sayfada her paneli farklı şekle sokmak yasaktır.

## 6. Kamera ve kurgu

Temel döngü:

1. E / mekânı kur.
2. N / karakterlerin mekânsal ilişkisini göster.
3. N / aksiyonu veya konuşmayı ilerlet.
4. Insert / el, telefon, nesne, ayak veya bakış detayı.
5. B veya C / duygusal teslim ya da komedi tahliyesi.

Kurallar:

- Her 5-8 resimli panelde bir mekânsal yeniden kurulum yapılır.
- Aynı konuşmada üç ardışık omuz üstü plan kullanılmaz.
- Kamera yüksekliği karakter gücünü anlatmak için değişir; rastgele dramatik açı kullanılmaz.
- Boy farkı olan çiftlerde her iki karakter sürekli aynı hizada gösterilmez.
- Yakın plan, önceki orta/geniş planın kurduğu duyguyu teslim eder; tek başına “güzel yüz” olmak için gelmez.
- Nesne insert'i daha sonra olay veya tema işlevi görmelidir.
- Sahne ekseni ve bakış yönü korunur. Bilinçli eksen kırılması varsa şaşkınlık/tehdit gerekçesi yazılır.

## 7. Anlatı mimarisi

### 7.1 Bölüm hedefi

Bir bölüm “çok olay” değil, tek baskın duygusal hareket taşır. Örnek hareketler:

- güvensizlikten meraka,
- kontrol hissinden küçük bir kayba,
- yanlış anlamadan gönülsüz iş birliğine,
- sosyal kaçınmadan seçici yakınlığa.

### 7.2 Romantik drama bölüm omurgası

| Beat | Yaklaşık bölüm payı | İşlev |
| --- | ---: | --- |
| Hook/cold open | %0-8 | İlişki vaadi veya çözülmemiş soru |
| Orientation | %8-18 | Zaman, mekân, karakter hedefi |
| Inciting contact | %18-32 | Karşılaşma, mesaj, hata, teklif veya zorunluluk |
| Social/inner friction | %32-55 | Dış konuşma ile iç niyet arasındaki fark |
| Micro-reversal | %55-70 | Beklenmeyen nezaket, yalan, bilgi veya yanlış okuma |
| Intimacy image | %70-82 | El, bakış, mesafe veya ortak nesne üzerinden yakınlık |
| Cost/complication | %82-94 | Yakınlaşmanın riski görünür olur |
| Turn/cliffhanger | %94-100 | Yeni soru; önceki beat'in duygusal sonucu |

Cold open kullanıldıysa geri dönüş açık bir zaman kartı, başlık veya palet değişimiyle işaretlenir. Her bölümde cold open zorunlu değildir.

### 7.3 Sahne kartı

Her sahne çizilmeden önce şu kart doldurulur:

```text
Sahne ID:
POV karakteri:
Dış hedef:
Gizli ihtiyaç:
Karşı tarafın hedefi:
Başlangıç duygusu -> bitiş duygusu:
Yeni bilgi:
Görsel motif:
Mekân yoğunluğu (BG-1/2/3):
Ana çizim modu (N/C/B/E):
Sahne sonu sorusu:
```

### 7.4 Bilgi dağıtımı

- Bir balonun görevi tek olmalıdır: bilgi, duygu, baskı, şaka veya kaçınma.
- Karakterlerin zaten bildiği geçmiş, birbirlerine açıklama diyaloğu olarak söyletilmez.
- Anlatıcı yalnız görüntünün veremediği bağlamı veya karaktere özgü yorum farkını ekler.
- İç ses, dış davranışla çeliştiğinde değerlidir.
- Aynı bilgi anlatıcı, diyalog ve görüntüyle üç kez tekrar edilmez.
- Her sahnede en az bir bilgi yalnız davranıştan okunur.

## 8. Diyalog ve speech sistemi

### 8.1 Karakter sesi

Her ana karakter için beş ses parametresi tutulur:

1. Cümle uzunluğu: kısa / orta / uzun.
2. Doğrudanlık: açık / dolaylı / kaçınan.
3. Mizah: kuru / sıcak / savunmacı / yok.
4. Sosyal maske: nazik / mesafeli / meydan okuyan / uyumlu.
5. Baskı altında değişim: hızlanır / susar / sertleşir / gevezeler.

İki karakter aynı kelime dağarcığı ve noktalama ritmiyle konuşamaz.

### 8.2 Balon metni

- İdeal balon 3-18 kelimedir; 25 kelimeyi geçen balon yeniden yazılır veya bölünür.
- Bir balonda tercihen 2-4 satır; her satır görsel olarak dengeli uzunlukta olur.
- Uzun konuşma tek dev balon yerine doğal nefes ve tepki anlarına bölünür.
- Balon sırası üstten alta ve soldan sağa tereddütsüz okunur.
- Kuyruk konuşanın ağız bölgesine yönelir ama yüze saplanmaz.
- Fısıltı kesik veya ince kontur; bağırma kalın/düzensiz kontur; iç düşünce ayrı görsel sözlük kullanır.
- Aynı sahnede balon stili sebepsiz değişmez.

### 8.3 Türkçe lettering

- Tümü büyük harf yalnız seçilen webtoon fontu küçük boyda okunabilirliğini koruyorsa kullanılır.
- Türkçe karakter seti eksiksiz olmalıdır: `ÇĞİÖŞÜ çğıöşü`.
- Satır sonunda tek harf, anlamsız hece veya yalnız bağlaç bırakılmaz.
- Ünlem ve üç nokta karakter sesiyle uyumlu, ölçülü kullanılır.
- Çeviri kokan devrik cümle yerine doğal Türkçe konuşma ritmi yazılır.
- Onur ekleri veya kültürel hitaplar kullanılacaksa seri sözlüğünde tutarlı karşılık tanımlanır.
- Yazı, görsel üretimden sonra vektör/ayrı katman olarak eklenir. Görsel modelden okunabilir yazı istenmez.

### 8.4 SFX

- SFX, resmin üstüne yapıştırılmış font değil, hareket yönüne bağlı grafik şekildir.
- Büyük darbe SFX'i panel sınırını aşabilir; gündelik küçük sesler nesneye yakın kalır.
- Aynı ses için seri boyunca aynı yazım ve genel form kullanılır.
- SFX altında karakter yüzü veya önemli el hareketi kaybolmaz.
- Korece SFX görünümünü taklit etmek için anlamsız glif üretilmez; Türkçe veya evrensel ses değeri kullanılır.

## 9. Özgün örnek bölüm şablonu

Çalışma adı: `Kıyıda Unutulan Ses`
Premise: Ses tasarımı öğrencisi Derya, vapur iskelesinde bulduğu bozuk bir saha kayıt cihazının sahibini ararken cihazda kendi adının geçtiği henüz yaşanmamış bir konuşma duyar. Cihazın sahibi Baran, kaydı hiç yapmadığını söyler.

İlk bölümün özgün akışı:

1. Cold open / B: Derya karanlık stüdyoda kulaklığı çıkarır; “Bu sesi yarın kaydedeceksin” cümlesinin etkisi yüzünde kalır.
2. G3 boşluk / iç ses: Gerçek zaman sorusu kurulur.
3. Insert: Kayıt cihazının kırmızı ışığı kendi kendine yanar.
4. Başlık kartı.
5. E / bir gün önce: Sabah vapur iskelesi, martı ve turnike ritmi.
6. N: Derya çevre sesi kaydeder; sosyal olarak insanlardan uzak durduğu davranışla gösterilir.
7. C: Bir martı mikrofon süngerini kapar; kısa komedi tahliyesi.
8. N: Baran süngeri geri getirir fakat yanlış kişiye ait kayıt cihazını Derya'ya uzatır.
9. Insert: İki el aynı cihaza gelir; parmaklar değmez, mesafe kalır.
10. Diyalog: Baran doğrudan, Derya kısa ve kaçınan konuşur.
11. Micro-reversal: Baran cihazın kendisine ait olmadığını fark eder ama cihaz onun öğrenci kartıyla etiketlidir.
12. B: Derya ilk kez Baran'a tam bakar; arka plan BG-1'e düşer.
13. Complication: Cihazdan Derya'nın adı duyulur.
14. Cliffhanger: Kayıttaki Baran sesi, ertesi gün buluşmamalarını söyler.

Bu örnek referans eserin karakter, nesne, mekân ve olay sırasını kullanmaz; yalnız genel romantik gizem ve dikey ritim ilkelerini uygular.

## 10. GPT Image üretim hattı

### 10.1 Yasak kısa yol

“40 panellik tam bölüm üret” veya “uzun webtoon sayfası üret” istenmez. Bu yaklaşım karakteri, anatomi ve render seviyesini sürükler; balon yerini ve mobil ritmi kontrol edilemez hale getirir.

### 10.2 Zorunlu ön üretim

1. Premise ve bölümün duygusal hareketi.
2. Beat sheet.
3. İki ana karakter için model sheet.
4. Yüz ifade sheet'i: nötr, küçük gülümseme, kaçınma, şaşkınlık, kızgınlık, utanç, chibi.
5. Kıyafet ve prop sheet.
6. BG-3 mekân master'ı.
7. N, C, B ve E modlarından en az birer stil testi.
8. Lettering'siz thumbnail şeridi.
9. Balon yerleşim maketi.
10. Art Director stil kilidi.

### 10.3 Üretim birimi

- Bir istek çoğunlukla tek panel üretir.
- En fazla aynı kamera kurulumuna ait iki küçük ardışık panel birlikte üretilebilir.
- Her panel prompt'u karakter kilidi, sahne kilidi, çizim modu, kamera, oyunculuk, ışık, boş alan ve kaçınılacaklar alanı taşır.
- Metin, logo, SFX ve panel numarası görsele ürettirilmez.

### 10.4 Prompt omurgası

```text
Completely original modern digital romance webtoon panel.
MODE: [N / C / B / E].
CHARACTER LOCK: [age, face geometry, hair silhouette, height, body build, outfit codes].
SCENE LOCK: [place, time, fixed props, palette].
SHOT: [shot size, lens feel, camera height, axis, composition].
ACTING: [gaze, brows, mouth, shoulders, hands, interpersonal distance].
RENDER: clean decisive dark gray line art, flat local colors, one-step cel shading,
selective soft atmosphere only where motivated, economical background detail.
LETTERING SPACE: [top-left / top-center / none], keep faces and hands clear.
OUTPUT: one silent panel, no text, speech bubbles, SFX, logo, watermark or border.
AVOID: painterly concept art, photorealism, glossy 3D skin, over-rendered fabric,
uniform cinematic detail, symmetrical doll faces, excessive bloom, malformed hands.
```

### 10.5 Mod eklentileri

N modu:

```text
Everyday acting, restrained facial expression, simple readable background,
line economy, no glamour pose, no dramatic rim light.
```

C modu:

```text
Intentional super-deformed comedy cutaway, simplified facial symbols and body,
flat graphic color, same character identifiers preserved, one-beat reaction only.
```

B modu:

```text
Emotion-first close-up, controlled eye detail, reduced background, one selective
soft glow, asymmetrical natural expression, no beauty-advertisement pose.
```

E modu:

```text
Readable place geography, clean perspective, sparse people silhouettes,
character art and environment sharing the same line/color treatment.
```

### 10.6 Düzeltme turları

1. Kompozisyon turu: kadraj, eksen, boşluk.
2. Model turu: yüz, saç, kıyafet, boy farkı.
3. Anatomi turu: el, eklem, temas, nesne.
4. Stil turu: kontur, düz renk, cel gölge, detay azaltma.
5. Kompozit turu: arka plan birliği, crop, panel sınırı.
6. Lettering turu: balon, metin, SFX.
7. Mobil önizleme turu.

Bir turda birden fazla temel sorunu değiştirmek yerine sorunlar sırayla kilitlenir.

## 11. İnsan eli hissi için son işlem

- Ham çıktının gereksiz cilt, kumaş ve arka plan dokusu azaltılır.
- Kontur kalınlığı ve rengi sahne genelinde normalize edilir.
- Saç içindeki rastgele teller silinir; karakteristik tutamlar korunur.
- Yüzler aynı güzellik filtresinden çıkarılmış görünüyorsa çene, göz aralığı ve kaş ritmi model sheet'e göre ayrıştırılır.
- Küçük aksesuarlar ve giysi dikişleri model sheet'e göre yeniden çizilir.
- Eller %200 yakınlıkta tek tek kontrol edilir.
- BG-2/BG-1 panellerde fazla detay boyanarak veya blur değil çizgi ekonomisiyle azaltılır.
- Renk paleti gradient map ile körlemesine eşitlenmez; ten, saç, kıyafet ve arka plan ayrı gruplarda ayarlanır.
- Balonların kapattığı bölgelerde gereksiz üretim emeği tutulmaz.
- Panel crop'u yüz eklemi, el parmağı veya önemli prop'u yanlış yerden kesmez.

## 12. Dosya ve katman sözleşmesi

```text
series-slug/
  bible/
    premise.md
    character-locks.md
    style-lock.md
    terminology-tr.md
  episode-001/
    beats.md
    thumbnails/
    prompts.json
    source/
      p001.clip
      p002.clip
    art/
      p001.webp
      p002.webp
    lettering/
      episode-001-lettering.clip
    export/
      001.webp
      002.webp
    qa/
      continuity.md
      export-manifest.json
```

Katman grupları:

```text
00_GUIDES
10_BG
20_CHARACTERS
30_FX
40_BALLOONS
50_TEXT
60_SFX
90_COLOR_GRADE
```

## 13. QA puan kartı

Toplam 100 puan. Yayın eşiği 85'tir. Aşağıdaki blocker'lardan biri varsa puan ne olursa olsun yayınlanmaz.

| Alan | Puan |
| --- | ---: |
| Karakter/model sürekliliği | 20 |
| Çizgi, renk ve mod tutarlılığı | 15 |
| Anatomi, el ve nesne teması | 15 |
| Yüz/beden oyunculuğu | 15 |
| Dikey ritim ve reveal | 15 |
| Diyalog, balon ve Türkçe lettering | 10 |
| Mekân/eksen sürekliliği | 5 |
| Export, mobil okunabilirlik ve asset bütünlüğü | 5 |

Blocker:

- Fazla/eksik parmak, kırık eklem veya fiziksel olarak imkânsız temas.
- Ana karakter yüzü, saçı, kıyafeti veya boy oranında açıklanamayan değişim.
- Okuma sırası belirsiz balon.
- Küçük ekranda okunmayan metin.
- Anlamsız/jenerik model yazısı, logo veya watermark.
- Telifli referans karakteri, paneli, diyalogu veya ayırt edici kompozisyonuyla belirgin benzerlik.
- Sahne ekseninin istemsiz kırılması.
- Aynı bölüm içinde gerekçesiz foto-gerçekçi/painterly stile geçiş.

### 13.1 AI görünümü hızlı taraması

Her soruya `evet` verilmelidir:

- Önemsiz panel, duygusal zirveden daha az render edilmiş mi?
- En az üç ifade şiddeti var mı: nötr, orta, güçlü?
- Komedi modu kontrollü ve kısa mı?
- Arka plan yoğunluğu BG-3 -> BG-2 -> BG-1 şeklinde değişiyor mu?
- Eller ve prop temasları tek tek doğrulandı mı?
- Karakterler sürekli “poz vermek” yerine eylem ortasında mı?
- Balon alanı kadrajda önceden ayrılmış mı?
- Aynı lens/ışık estetiği bütün panellere uygulanmamış mı?
- Düz yerel renk ve cel gölge baskın mı?
- Her B modu yakın plan hikâyede yeni bir duygu teslim ediyor mu?

## 14. Stil master kabul testi

Tek güzel görsel master değildir. Aday stil aşağıdaki 12 karelik paketi geçmelidir:

1. Kadın karakter önden N.
2. Kadın karakter profil N.
3. Erkek karakter 3/4 N.
4. İki karakter tam boy ve doğru boy farkı.
5. İki karakter otururken diyalog.
6. El + ortak prop insert'i.
7. Dış mekân BG-3.
8. İç mekân BG-2.
9. Kadın B yakın plan.
10. Erkek B yakın plan.
11. Kadın C reaksiyon.
12. İki karakterli C yanlış anlama.

Koşullar:

- İki farklı gün ışığı ve bir gece ışığı.
- En az iki kıyafet, fakat her kıyafet kendi içinde tutarlı.
- Üç art arda panelde yüz ve saç sürekliliği.
- B ve C modlarının aynı karakter olduğu açıkça okunmalı.
- Paket QA'dan en az 85 almalı.

Mevcut `master-refined.png` bu testin yalnız tek sahneli B/E ağırlıklı kısmını gösterir; N/C modu, lettering alanı ve seri üretim ekonomisini kanıtlamadığı için master olarak reddedilmiştir. Karşılaştırma artefaktı olarak tutulur.

## 15. Üretim kabul kriterleri

Bir pilot bölüm üretimine başlamadan önce:

- Özgün premise, karakter ve olay akışı onaylandı.
- 12 karelik style-master testi geçti.
- Beat sheet ve sahne kartları tamamlandı.
- Thumbnail şeridi mobil önizlemede okundu.
- Balon metinleri görsel üretimden önce taslaklandı.
- Her panel N/C/B/E ve BG-1/2/3 etiketi aldı.
- Prompt kayıt şeması ve provenance dosyası hazır.
- Panel başına üretim/değişiklik bütçesi belirlendi.
- Telif benzerliği ve görsel QA sorumlusu belirlendi.

## 16. Resmî teknik kaynaklar

- [WEBTOON CANVAS: uzun bölüm görsellerinin 800 x 1280 px azami dilimlere optimize edilmesi](https://www.webtoons.com/en/notice/detail?noticeNo=1766)
- [WEBTOON Comics Tips: metin, görsel ve panel aralığıyla pacing](https://www.webtoons.com/en/canvas/comics-tips/layout-control-pacing-with-text-images/viewer?episode_no=25&title_no=892865)
- [Clip Studio Paint: webtoon ekran alanı ve dikey bölerek export](https://help.clip-studio.com/en-us/manual_en/540_comic/Webtoons.htm)
- [Clip Studio Paint: Webtoon Preview ile akıllı telefonda kontrol](https://help.clip-studio.com/en-us/manual_en/840_options/Companion_Mode.htm)
- [WEBTOON CANVAS üretim aşamaları: thumbnail, sketch, inking, color, lettering/finalizing](https://tips.clip-studio.com/id-id/articles/4891?org=1)
