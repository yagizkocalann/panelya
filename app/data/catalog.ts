export type PanelTone = "coral" | "mint" | "violet" | "blue" | "amber" | "rose";

export type PublicMediaVariant = {
  src: string;
  width: number;
  height: number;
  mimeType: "image/webp";
};

export type StoryPanel = {
  id: string;
  scene: string;
  caption?: string;
  dialogue?: string;
  tone: PanelTone;
  align?: "left" | "right";
  image?: {
    src: string;
    alt: string;
    width: number;
    height: number;
    variants?: PublicMediaVariant[];
  };
};

export type Episode = {
  slug: string;
  number: number;
  title: string;
  publishedAt: string;
  readTime: string;
  panels: StoryPanel[];
};

export type Series = {
  slug: string;
  title: string;
  eyebrow: string;
  creator: string;
  description: string;
  longDescription: string;
  status: "Devam Ediyor" | "Tamamlandı";
  genres: string[];
  tone: PanelTone;
  updatedAt: string;
  rating: number;
  followers: string;
  isNew?: boolean;
  coverImage?: string;
  coverImageVariants?: PublicMediaVariant[];
  coverPosition?: string;
  episodes: Episode[];
};

const nightShiftPanels: StoryPanel[] = [
  {
    id: "rain-city",
    scene: "Yağmurun altında, gece yarısı ışıklarıyla parlayan bir İstanbul sokağı.",
    caption: "İstanbul, 02.13 — şehrin uyumayı unuttuğu saat.",
    tone: "blue",
  },
  {
    id: "last-bus",
    scene: "Boş bir otobüs durağında kırmızı şemsiyeli genç kurye Ece bekliyor.",
    dialogue: "Son sefer de gittiyse bugün gerçekten rekor kırdım.",
    tone: "coral",
    align: "left",
  },
  {
    id: "mystery-package",
    scene: "Ece'nin çantasındaki isimsiz paket mint renkli bir ışıkla titreşiyor.",
    caption: "Teslimat adresi: Yarın, saat 02.17.",
    tone: "mint",
  },
  {
    id: "stranger",
    scene: "Durak camının ötesinde yüzü gölgede kalan uzun bir yabancı beliriyor.",
    dialogue: "O paketi açarsan, bu gece hiç yaşanmamış olacak.",
    tone: "violet",
    align: "right",
  },
  {
    id: "clock",
    scene: "Dijital saat 02.16'dan 02.15'e geriye doğru atlıyor.",
    caption: "Bir dakika önce.",
    tone: "amber",
  },
  {
    id: "choice",
    scene: "Ece bir eli pakette, diğer eli telefonunda; yağmur havada asılı kalmış.",
    dialogue: "Peki ya açmazsam?",
    tone: "rose",
    align: "left",
  },
  {
    id: "answer",
    scene: "Yabancı ilk kez ışığa çıkıyor; gözlerinde aynı geri sayım yansıyor.",
    dialogue: "O zaman yarın seni bulamayacağım.",
    tone: "blue",
    align: "right",
  },
];

const compactPanels = (tone: PanelTone, title: string): StoryPanel[] => [
  {
    id: `${title}-opening`,
    scene: `${title} için atmosferik açılış karesi.`,
    caption: "Yeni bir hikâye başlıyor.",
    tone,
  },
  {
    id: `${title}-hook`,
    scene: `${title} kahramanının karar anı.`,
    dialogue: "Geri dönüş yok.",
    tone,
    align: "right",
  },
];

const tomorrowVoicePanels: StoryPanel[] = [
  {
    id: "tomorrow-voice-01",
    scene: "Gece ses laboratuvarında Derya, yarından geldiğini gösteren kaydı ilk kez dinler.",
    caption: "Kayıttaki Derya · yarın",
    dialogue: "Baran… bu kez gelme.",
    tone: "blue",
    image: { src: "/images/yarinki-ses/panel-001-mode-b-v1-clean.webp", alt: "Karanlık ses laboratuvarında kulaklıkla kayıt dinleyen Derya ve kırmızı kayıt ışığı.", width: 972, height: 1619 },
  },
  {
    id: "tomorrow-voice-02",
    scene: "Eski kayıt cihazının boş ekranı ve kırmızı LED'i yakın planda görünür.",
    caption: "Tarih yarındı.",
    tone: "blue",
    image: { src: "/images/yarinki-ses/panel-002-insert-v1-clean.webp", alt: "Karanlık masada ekranı parlayan eski dijital ses kayıt cihazının yakın planı.", width: 972, height: 1619 },
  },
  {
    id: "tomorrow-voice-03",
    scene: "Derya'nın gözünde kırmızı kayıt ışığı yansır.",
    caption: "Ama o zaman onu henüz tanımıyordum.",
    tone: "violet",
    image: { src: "/images/yarinki-ses/panel-003-mode-b-v1-clean.webp", alt: "Derya'nın şaşkın gözünün ve kırmızı kayıt ışığının dramatik yakın planı.", width: 1122, height: 1402 },
  },
  {
    id: "tomorrow-voice-04",
    scene: "Ses dalgası iki yüzün profiline dönüşerek bölüm başlığı için boşluk açar.",
    tone: "mint",
    image: { src: "/images/yarinki-ses/panel-004-title-v1-clean.webp", alt: "İki yüz profiline dönüşen ince bir ses dalgasıyla sade bölüm geçişi.", width: 864, height: 1821 },
  },
  {
    id: "tomorrow-voice-05",
    scene: "Bir gün önce Derya, Haliç kıyısındaki üniversite ses kayıt gezisinde tek başına durur.",
    caption: "24 saat önce · Haliç kıyısı",
    tone: "blue",
    image: { src: "/images/yarinki-ses/panel-005-mode-e-v2-clean.webp", alt: "Haliç kıyısında mikrofonuyla tek başına duran Derya ve uzaktaki İstanbul silueti.", width: 1122, height: 1402 },
  },
  {
    id: "tomorrow-voice-06",
    scene: "Derya küçük mikrofonunu korkuluğa bağlayıp ortam sesini ayarlar.",
    caption: "Bir gün önce, seslerden başka kimsenin peşine düşmüyordum.",
    tone: "mint",
    image: { src: "/images/yarinki-ses/panel-006-mode-n-v1-clean.webp", alt: "Haliç kıyısında mikrofonunu dikkatle ayarlayan Derya.", width: 1122, height: 1402 },
  },
  {
    id: "tomorrow-voice-07",
    scene: "Bir martı mikrofonun tüylü rüzgârlığını kapınca Derya peşinden koşar.",
    tone: "amber",
    image: { src: "/images/yarinki-ses/panel-007-mode-c-v1-clean.webp", alt: "Mikrofon rüzgârlığını kaçıran martının peşinden koşan chibi Derya.", width: 1097, height: 1434 },
  },
  {
    id: "tomorrow-voice-08",
    scene: "Derya döndüğünde Baran rüzgârlığı ona uzatır.",
    dialogue: "— Sanırım bu sizden kaçtı.\n— Mikrofon süngeri.",
    tone: "mint",
    image: { src: "/images/yarinki-ses/panel-008-mode-n-v1-clean.webp", alt: "Baran'ın bulduğu mikrofon rüzgârlığını Derya'ya uzattığı ilk karşılaşma.", width: 1003, height: 1568 },
  },
  {
    id: "tomorrow-voice-09",
    scene: "İkisinin eli aynı rüzgârlığa yaklaşır ama birbirine değmez.",
    tone: "rose",
    image: { src: "/images/yarinki-ses/panel-009-insert-v2-clean.webp", alt: "Aynı mikrofon rüzgârlığına uzanan Derya ve Baran'ın elleri arasında kalan küçük boşluk.", width: 1002, height: 1570 },
  },
  {
    id: "tomorrow-voice-10",
    scene: "Baran yerde bulduğu eski kayıt cihazını Derya'ya gösterir.",
    dialogue: "Bu da sizin mi?",
    tone: "blue",
    image: { src: "/images/yarinki-ses/panel-010-mode-n-v1-clean.webp", alt: "Baran'ın eski siyah kayıt cihazını Derya'ya gösterdiği Haliç kıyısı sahnesi.", width: 1122, height: 1402 },
  },
  {
    id: "tomorrow-voice-11",
    scene: "Derya cihaz üzerindeki etikette kendi öğrenci numarasını fark eder.",
    dialogue: "Numara benim.",
    tone: "violet",
    image: { src: "/images/yarinki-ses/panel-011-mode-n-v1-clean.webp", alt: "Kayıt cihazındaki etiketi şaşkınlıkla inceleyen Derya.", width: 864, height: 1821 },
  },
  {
    id: "tomorrow-voice-12",
    scene: "Derya'nın zihninde cihaz, kablo ve kırmızı ışıkla ilgili sorular üst üste gelir.",
    caption: "Bu cihazı hiç görmedim. Neden bende kayıtlı? Neden o tutuyor?",
    dialogue: "Evet.",
    tone: "amber",
    image: { src: "/images/yarinki-ses/panel-012-mode-c-v2-clean.webp", alt: "Kayıt cihazı, soru biçimli kablo ve kırmızı ışık arasında endişelenen chibi Derya.", width: 864, height: 1821 },
  },
  {
    id: "tomorrow-voice-13",
    scene: "Kısa kulaklık kablosu Derya ile Baran'ı birlikte dinlemek için yaklaşmaya zorlar.",
    dialogue: "— Çalışıyor mu?\n— Birlikte dinlersek öğreniriz.",
    tone: "mint",
    image: { src: "/images/yarinki-ses/panel-013-mode-n-v1-clean.webp", alt: "Aynı kayıt cihazına bağlı kısa kulaklık kablosuyla yan yana dinleyen Derya ve Baran.", width: 887, height: 1774 },
  },
  {
    id: "tomorrow-voice-14",
    scene: "Baran geri çekilip kulaklığı Derya'ya bırakır; Derya bu küçük nezaketi fark eder.",
    dialogue: "Siz dinleyin. Ben beklerim.",
    tone: "rose",
    image: { src: "/images/yarinki-ses/panel-014-mode-b-v1-clean.webp", alt: "Kulaklığı Derya'ya bırakarak saygılı bir mesafede bekleyen Baran.", width: 887, height: 1774 },
  },
  {
    id: "tomorrow-voice-15",
    scene: "Kayıt cihazı Derya'nın ellerinde kendiliğinden çalışmaya başlar.",
    tone: "coral",
    image: { src: "/images/yarinki-ses/panel-015-insert-v1-clean.webp", alt: "Derya'nın ellerindeki kayıt cihazında kendiliğinden yanan kırmızı LED'in yakın planı.", width: 930, height: 1692 },
  },
  {
    id: "tomorrow-voice-16",
    scene: "Derya ile Baran cihazdan gelen Derya sesini aynı anda duyar.",
    caption: "Kayıttaki Derya",
    dialogue: "Baran, bir daha yalan söyleme.",
    tone: "violet",
    image: { src: "/images/yarinki-ses/panel-016-mode-n-v1-clean.webp", alt: "Aktif kayıt cihazına aynı anda kaygıyla bakan Derya ve Baran.", width: 864, height: 1821 },
  },
  {
    id: "tomorrow-voice-17",
    scene: "Derya Baran'a ilk kez doğrudan bakar; Baran'ın sakinliği bozulur.",
    dialogue: "— Adımı nereden biliyorsunuz?\n— Bilmiyorum.",
    tone: "blue",
    image: { src: "/images/yarinki-ses/panel-017-mode-b-v1-clean.webp", alt: "Kayıt cihazını aralarında tutarken kuşkuyla göz göze gelen Derya ve Baran.", width: 862, height: 1825 },
  },
  {
    id: "tomorrow-voice-18",
    scene: "Derya ve Baran, aralarında yerde duran kayıt cihazına hiç dokunmadan karşı karşıya kalır.",
    caption: "İlk yalanı bu muydu?",
    tone: "blue",
    image: { src: "/images/yarinki-ses/panel-018-mode-e-v1-clean.webp", alt: "Haliç kıyısında aralarında kayıt cihazı bulunan Derya ve Baran'ın geniş final planı.", width: 862, height: 1825 },
  },
];

export const seriesCatalog: Series[] = [
  {
    slug: "gece-vardiyasi",
    title: "Gece Vardiyası",
    eyebrow: "Zamanı geri saran bir teslimat",
    creator: "Panelya Originals",
    description:
      "Gece kuryesi Ece, teslim edilmemesi gereken bir paket yüzünden İstanbul'un kayıp dakikalarına sıkışır.",
    longDescription:
      "Ece için gece vardiyası, şehrin kimsenin görmediği yüzünü ezberlemek demektir. Fakat üzerinde yalnızca ertesi günün tarihi yazan bir paket, bildiği bütün rotaları bozar. Her teslimatta zaman biraz daha geri sarılırken Ece, geleceği kurtarmak ile geçmişte kaybettiği birini geri getirmek arasında seçim yapmak zorunda kalır.",
    status: "Devam Ediyor",
    genres: ["Gizem", "Bilim Kurgu", "Dram"],
    tone: "coral",
    updatedAt: "Bugün",
    rating: 4.9,
    followers: "12,8 B",
    episodes: [
      {
        slug: "bolum-3",
        number: 3,
        title: "Kayıp Dakika",
        publishedAt: "18 Temmuz 2026",
        readTime: "7 dk",
        panels: compactPanels("violet", "Kayıp Dakika"),
      },
      {
        slug: "bolum-2",
        number: 2,
        title: "Yarınki Adres",
        publishedAt: "12 Temmuz 2026",
        readTime: "8 dk",
        panels: compactPanels("mint", "Yarınki Adres"),
      },
      {
        slug: "bolum-1",
        number: 1,
        title: "Son Teslimat",
        publishedAt: "5 Temmuz 2026",
        readTime: "9 dk",
        panels: nightShiftPanels,
      },
    ],
  },
  {
    slug: "bir-bilet-uzaginda",
    title: "Bir Bilet Uzağında",
    eyebrow: "Yağmur, son vapur ve havalanan bir bilet",
    creator: "Panelya Originals · Görsel Pilot",
    description:
      "Deniz ve Aras, yağmurdan sonra bir vapur iskelesinde aynı bilete uzanırken beklenmedik bir anı paylaşır.",
    longDescription:
      "Deniz eve yetişmeye, Aras ise son vapuru kaçırmamaya çalışır. Rüzgârın sürüklediği boş bir bilet ikisini aynı noktada durdurur. Bu tek bölümlük görsel pilot; Panelya'nın özgün romantik webtoon çizgi, renk ve dikey ritim denemesidir.",
    status: "Devam Ediyor",
    genres: ["Romantizm", "Günlük Yaşam"],
    tone: "mint",
    updatedAt: "Bugün",
    rating: 4.8,
    followers: "Yeni",
    isNew: true,
    coverImage: "/images/bir-bilet-uzaginda-bolum-1.webp",
    coverPosition: "50% 96%",
    episodes: [
      {
        slug: "bolum-1",
        number: 1,
        title: "Rüzgâra Karışan",
        publishedAt: "18 Temmuz 2026",
        readTime: "2 dk",
        panels: [
          {
            id: "ferry-ticket-encounter",
            scene: "Yağmurdan sonra bir İstanbul vapur iskelesinde Deniz ve Aras'ın uçan bir bilete birlikte uzandığı ilk karşılaşma.",
            tone: "mint",
            image: {
              src: "/images/bir-bilet-uzaginda-bolum-1.webp",
              alt: "Dört panelli özgün romantik webtoon pilotu: yağmurlu vapur iskelesinde karşılaşan Deniz ve Aras, uçan bilete uzanır ve göz göze gelir.",
              width: 864,
              height: 1821,
            },
          },
        ],
      },
    ],
  },
  {
    slug: "yarinki-ses",
    title: "Yarınki Ses",
    eyebrow: "Yarından gelen bir kayıt, bugün söylenen ilk yalan",
    creator: "Panelya Originals · Özgün Görsel Pilot",
    description:
      "Ses tasarımı öğrencisi Derya, üzerinde kendi numarası bulunan eski bir cihazda yarın Baran'la yapacağı konuşmayı bulur.",
    longDescription:
      "Derya için sesler insanlardan daha güvenilirdir. Haliç kıyısındaki bir kayıt gezisinde tanıştığı Baran'ın bulduğu cihaz ise bu inancı bozar: cihazda Derya'nın kendi sesi, henüz yaşanmamış bir güne ve Baran'ın söyleyeceği bir yalana işaret eder. Her seçim kaydı biraz değiştirirken ikisi, geleceği önceden duymanın onu engellemeye yetip yetmediğini keşfetmek zorunda kalır.",
    status: "Devam Ediyor",
    genres: ["Romantizm", "Gizem", "Dram"],
    tone: "blue",
    updatedAt: "Bugün",
    rating: 0,
    followers: "Yeni",
    isNew: true,
    coverImage: "/images/yarinki-ses/panel-017-mode-b-v1-clean.webp",
    coverPosition: "50% 34%",
    episodes: [
      {
        slug: "bolum-1",
        number: 1,
        title: "Kayıtta Ben Varım",
        publishedAt: "18 Temmuz 2026",
        readTime: "8 dk",
        panels: tomorrowVoicePanels,
      },
    ],
  },
  {
    slug: "yankinin-bahcesi",
    title: "Yankının Bahçesi",
    eyebrow: "Hatıralar toprağın altında büyür",
    creator: "Lal Atölye",
    description: "Botanikçi Duru, insanların unuttuğu anılardan çiçek açan gizli bir sera keşfeder.",
    longDescription: "Her çiçek bir anıyı saklıyor; bazı anılar ise sahiplerine dönmek istemiyor.",
    status: "Devam Ediyor",
    genres: ["Fantastik", "Dram"],
    tone: "mint",
    updatedAt: "2 saat önce",
    rating: 4.7,
    followers: "8,4 B",
    isNew: true,
    episodes: [{ slug: "bolum-1", number: 1, title: "Tohum", publishedAt: "18 Temmuz 2026", readTime: "6 dk", panels: compactPanels("mint", "Tohum") }],
  },
  {
    slug: "sifir-numara",
    title: "Sıfır Numara",
    eyebrow: "Şehrin görünmeyen basketbol ligi",
    creator: "Kuzey Çizgi",
    description: "Mahalle sahasının en sessiz oyuncusu, geceleri kuralları değişen bir lige çağrılır.",
    longDescription: "Arda'nın tek kozu, kimsenin ölçemediği oyun görüşüdür.",
    status: "Devam Ediyor",
    genres: ["Spor", "Gençlik"],
    tone: "amber",
    updatedAt: "Dün",
    rating: 4.6,
    followers: "6,1 B",
    episodes: [{ slug: "bolum-1", number: 1, title: "Seçmeler", publishedAt: "17 Temmuz 2026", readTime: "7 dk", panels: compactPanels("amber", "Seçmeler") }],
  },
  {
    slug: "kirmizi-hat",
    title: "Kırmızı Hat",
    eyebrow: "Son metro, ilk şüpheli",
    creator: "Mert Ayaz",
    description: "Bir metro makinisti, her gece aynı boş vagonda ortaya çıkan yolcunun izini sürer.",
    longDescription: "Son seferin güvenlik kayıtları her sabah kendini siliyor.",
    status: "Tamamlandı",
    genres: ["Gerilim", "Suç"],
    tone: "rose",
    updatedAt: "3 gün önce",
    rating: 4.8,
    followers: "19,2 B",
    episodes: [{ slug: "bolum-1", number: 1, title: "Son Sefer", publishedAt: "15 Temmuz 2026", readTime: "10 dk", panels: compactPanels("rose", "Son Sefer") }],
  },
  {
    slug: "iki-kisilik-gezegen",
    title: "İki Kişilik Gezegen",
    eyebrow: "Dünya uzakta, mesajın çok yakın",
    creator: "Nova Oda",
    description: "İki rakip astronot, terk edilmiş bir istasyonda aynı oksijeni ve aynı sırrı paylaşır.",
    longDescription: "Kurtarma ekibi gelene kadar birbirlerine güvenmek zorundalar.",
    status: "Devam Ediyor",
    genres: ["Romantizm", "Bilim Kurgu"],
    tone: "violet",
    updatedAt: "4 gün önce",
    rating: 4.5,
    followers: "5,9 B",
    isNew: true,
    episodes: [{ slug: "bolum-1", number: 1, title: "Yörünge", publishedAt: "14 Temmuz 2026", readTime: "8 dk", panels: compactPanels("violet", "Yörünge") }],
  },
  {
    slug: "apartman-13",
    title: "Apartman 13",
    eyebrow: "Her katta başka bir sır",
    creator: "Üçüncü Kat",
    description: "Yeni taşındığı apartmanda on üçüncü katı yalnızca geceleri gören Nisan, komşularının sırlarını toplar.",
    longDescription: "Asansör düğmelerinde olmayan bir kat, binanın bütün geçmişini saklıyor.",
    status: "Devam Ediyor",
    genres: ["Komedi", "Gizem"],
    tone: "blue",
    updatedAt: "1 hafta önce",
    rating: 4.4,
    followers: "3,7 B",
    isNew: true,
    episodes: [{ slug: "bolum-1", number: 1, title: "Taşınma Günü", publishedAt: "10 Temmuz 2026", readTime: "6 dk", panels: compactPanels("blue", "Taşınma Günü") }],
  },
];

export const featuredSeries = seriesCatalog[0];

export function getSeries(slug: string) {
  return seriesCatalog.find((series) => series.slug === slug);
}

export function getEpisode(series: Series, episodeSlug: string) {
  return series.episodes.find((episode) => episode.slug === episodeSlug);
}

export function getAdjacentEpisodes(series: Series, episode: Episode) {
  const ascending = [...series.episodes].sort((a, b) => a.number - b.number);
  const index = ascending.findIndex((candidate) => candidate.slug === episode.slug);
  return {
    previous: index > 0 ? ascending[index - 1] : undefined,
    next: index < ascending.length - 1 ? ascending[index + 1] : undefined,
  };
}

export function allGenres() {
  return Array.from(new Set(seriesCatalog.flatMap((series) => series.genres))).sort((a, b) => a.localeCompare(b, "tr"));
}
