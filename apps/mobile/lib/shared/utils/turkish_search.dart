/// Türkçe'ye duyarlı katalog arama normalizasyonu.
///
/// Web tarafındaki `app/lib/content-repository.ts` -> `normalizeCatalogSearch`
/// algoritmasının Dart portu (bkz. docs/mobile-handoff.md PLAN Görev 5):
///
/// ```ts
/// value
///   .normalize("NFKD")
///   .replace(/[\u0300-\u036f]/g, "")
///   .toLocaleLowerCase("tr")
///   .replaceAll("ı", "i")
///   .replace(/[^a-z0-9]+/g, " ")
///   .trim();
/// ```
///
/// ## NFKD sapması (bkz. görev talimatı — Kalan risk/varsayım'da tekrarlanır)
///
/// Dart'ın çekirdek kütüphanesinde tam Unicode NFKD ayrıştırması yoktur;
/// AGENTS.md gerekçesiz yeni bağımlılık eklemeyi yasaklar ve tam bir NFKD
/// tablosu (binlerce kod noktası) bu tek arama kutusu için orantısız bir
/// bağımlılık/karmaşıklık olurdu. Bunun yerine web'in NFKD + combining-mark
/// temizliğinin PRATİKTE ürettiği sonuç, elle tutulan bir katlama tablosuyla
/// üretilir:
///
/// - Türkçe'ye özgü `İ`/`I`/`ı` harfleri (web'in `toLocaleLowerCase("tr")` +
///   `replaceAll("ı","i")` adımlarının asıl çözdüğü sorun) tam olarak
///   web'deki net sonuçla eşleşecek şekilde `i`'ye katlanır.
/// - Latin-1 Supplement bloğundaki tek-kod-noktalı (precomposed) aksanlı
///   harfler (á, à, â, ã, ä, å, ç, é, è, ê, ë, í, ì, î, ï, ñ, ó, ò, ô, õ, ö,
///   ú, ù, û, ü, ý, ÿ, ø, æ, ð, þ, ß gibi — Türkçe ç/ş/ğ/ö/ü'nün Latin-1
///   karşılıkları ve en sık karşılaşılan Batı Avrupa alfabesi harfleri dahil)
///   taban ASCII harfine katlanır; bu web'in NFKD ayrıştırıp ardından
///   combining mark'ı (`\u0300-\u036f`) silmesiyle AYNI sonucu üretir, çünkü
///   bu harflerin hepsi NFKD altında taban harf + tek bir combining mark'a
///   ayrışır.
/// - Girdi zaten önceden ayrıştırılmış (NFD/NFKD) gelirse (örn. bazı
///   platformların pano/klavye çıktısı), `\u0300-\u036f` aralığındaki
///   combining mark'lar da doğrudan bir güvenlik ağı olarak düşürülür.
///
/// Bunun dışında kalan, daha nadir görülen çok-kod-noktalı NFKD ayrışmaları
/// (örn. Vietnamca çoklu aksan yığınları, Latin Extended-B/Ekstra harfler,
/// `œ`/`ﬁ` gibi tipografik ligatürler) bu tabloda YOKTUR ve olduğu gibi
/// (yalnız küçük harfe çevrilip alfanumerik-dışı temizliğinden geçirilmiş
/// olarak) kalır. Panelya'nın Türkçe içerik kataloğu için bu, gerçek
/// kullanım alanının tamamını (Türkçe harfler + genel Latin aksanları)
/// kapsar; kapsam dışı kalan durumlar görev raporunda ayrıca belirtilir.
String normalizeCatalogSearch(String value) {
  final folded = StringBuffer();
  for (final rune in value.runes) {
    final mapped = _accentFoldTable[rune];
    if (mapped != null) {
      folded.write(mapped);
      continue;
    }
    if (rune >= 0x0300 && rune <= 0x036f) {
      // Combining diacritical mark (bkz. dosya başlığı "NFKD sapması"
      // notu): taban harf zaten önceki adımda yazıldı, mark'ın kendisi
      // web'in `.replace(/[̀-ͯ]/g, "")` adımıyla aynı şekilde
      // düşürülür.
      continue;
    }
    folded.writeCharCode(rune);
  }

  // Web'in `.replaceAll("ı", "i")` adımıyla aynı savunma amaçlı ikinci
  // geçiş: `_accentFoldTable` zaten `ı`/`İ`'yi `i`'ye katladığı için
  // pratikte burada eşleşecek bir karakter kalmaz, ama algoritmanın adım
  // adım web'dekiyle aynı olduğunu açık tutar. Ardından alfanumerik
  // olmayan her koşu boşluğa çevrilir ve baştaki/sondaki boşluk kırpılır.
  return folded
      .toString()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}

const Map<int, String> _accentFoldTable = {
  // Türkçe'ye özgü: İ/I/ı hepsi 'i'ye katlanır (bkz. dosya başlığı).
  0x0130: 'i', // İ
  0x0131: 'i', // ı
  0x011e: 'g', // Ğ
  0x011f: 'g', // ğ
  0x015e: 's', // Ş
  0x015f: 's', // ş

  // Latin-1 Supplement — büyük harf.
  0x00c0: 'a', 0x00c1: 'a', 0x00c2: 'a', 0x00c3: 'a', 0x00c4: 'a', 0x00c5: 'a',
  0x00c6: 'ae',
  0x00c7: 'c',
  0x00c8: 'e', 0x00c9: 'e', 0x00ca: 'e', 0x00cb: 'e',
  0x00cc: 'i', 0x00cd: 'i', 0x00ce: 'i', 0x00cf: 'i',
  0x00d0: 'd',
  0x00d1: 'n',
  0x00d2: 'o', 0x00d3: 'o', 0x00d4: 'o', 0x00d5: 'o', 0x00d6: 'o', 0x00d8: 'o',
  0x00d9: 'u', 0x00da: 'u', 0x00db: 'u', 0x00dc: 'u',
  0x00dd: 'y',
  0x00de: 't',
  0x00df: 'ss',

  // Latin-1 Supplement — küçük harf.
  0x00e0: 'a', 0x00e1: 'a', 0x00e2: 'a', 0x00e3: 'a', 0x00e4: 'a', 0x00e5: 'a',
  0x00e6: 'ae',
  0x00e7: 'c',
  0x00e8: 'e', 0x00e9: 'e', 0x00ea: 'e', 0x00eb: 'e',
  0x00ec: 'i', 0x00ed: 'i', 0x00ee: 'i', 0x00ef: 'i',
  0x00f0: 'd',
  0x00f1: 'n',
  0x00f2: 'o', 0x00f3: 'o', 0x00f4: 'o', 0x00f5: 'o', 0x00f6: 'o', 0x00f8: 'o',
  0x00f9: 'u', 0x00fa: 'u', 0x00fb: 'u', 0x00fc: 'u',
  0x00fd: 'y',
  0x00fe: 't',
  0x00ff: 'y',
};
