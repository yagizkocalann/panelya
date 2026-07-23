import type { PanelTone, Series } from "./catalog";

export const LOCAL_DUMMY_SERIES_COUNT = 92;

const titleStarts = [
  "Ay Işığı", "Sessiz", "Kayıp", "Gece", "Kırık", "Son", "Mavi", "Gizli", "Uzak", "Yarım", "Ters", "Boş",
] as const;
const titleEnds = [
  "İstasyonu", "Defteri", "Sokağı", "Bahçesi", "Frekansı", "Postanesi", "Dairesi", "Haritası",
] as const;
const episodeTitles = ["İlk İşaret", "Kapı Aralığı", "Geri Sayım", "Beklenmeyen Mesaj", "Sessiz Tanık", "Yeni Rota"] as const;
const tones: PanelTone[] = ["coral", "mint", "violet", "blue", "amber", "rose"];
const genrePairs = [
  ["Romantizm", "Dram"],
  ["Gizem", "Gerilim"],
  ["Fantastik", "Macera"],
  ["Bilim Kurgu", "Dram"],
  ["Komedi", "Günlük Yaşam"],
  ["Gençlik", "Spor"],
] as const;

function slugify(value: string) {
  return value
    .toLocaleLowerCase("tr")
    .replaceAll("ı", "i")
    .replaceAll("ğ", "g")
    .replaceAll("ü", "u")
    .replaceAll("ş", "s")
    .replaceAll("ö", "o")
    .replaceAll("ç", "c")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

export const localDummySeriesCatalog: Series[] = Array.from({ length: LOCAL_DUMMY_SERIES_COUNT }, (_, index) => {
  const title = `${titleStarts[index % titleStarts.length]} ${titleEnds[Math.floor(index / titleStarts.length) % titleEnds.length]}`;
  const tone = tones[index % tones.length];
  const number = String(index + 1).padStart(3, "0");
  const episodeTitle = episodeTitles[index % episodeTitles.length];
  const genres = [...genrePairs[index % genrePairs.length]];

  return {
    slug: `yerel-demo-${number}-${slugify(title)}`,
    title,
    eyebrow: `Yerel katalog testi #${number}`,
    creator: "Panelya Yerel Demo",
    description: "Kart, filtre, sayfalama ve responsive görünüm testi için oluşturulmuş sentetik seri.",
    longDescription: "Bu kayıt yalnızca yerel geliştirme ortamındaki arayüz ve veri akışı testlerinde kullanılır; production içeriği değildir.",
    status: index % 9 === 0 ? "Tamamlandı" : "Devam Ediyor",
    genres,
    tone,
    updatedAt: index < 12 ? "Bugün" : `${Math.ceil((index - 11) / 8)} gün önce`,
    rating: Number((3.8 + (index % 12) / 10).toFixed(1)),
    followers: "Demo",
    isNew: true,
    episodes: [
      {
        slug: "bolum-1",
        number: 1,
        title: episodeTitle,
        publishedAt: "23 Temmuz 2026",
        readTime: "1 dk",
        panels: [
          {
            id: `yerel-demo-${number}-placeholder`,
            scene: `${title} için yerel bölüm placeholder karesi.`,
            caption: "Bu bölüm yalnızca yerel arayüz testi için hazırlanmıştır.",
            tone,
          },
        ],
      },
    ],
  };
});
