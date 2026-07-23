import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { AdSlot } from "./components/AdSlot";
import { GenreDirectoryLinks } from "./components/GenreDirectoryLinks";
import { SeriesCard } from "./components/SeriesCard";
import { SiteFooter } from "./components/SiteFooter";
import { SiteHeader } from "./components/SiteHeader";
import { listPublishedEpisodeUpdates, listPublishedGenres, listPublishedSeries } from "./lib/content-repository";

export const metadata: Metadata = {
  title: "Panelya — Kaydır, keşfet, hikâyeye gir",
  description: "Özgün Türkçe dikey çizgi hikâyeleri keşfet ve ücretsiz oku.",
  alternates: { canonical: "/" },
  openGraph: {
    title: "Panelya — Kaydır, keşfet, hikâyeye gir",
    description: "Özgün Türkçe dikey çizgi hikâyeleri keşfet ve ücretsiz oku.",
    url: "/",
  },
};

type LegacyCatalogQuery = { q?: string; genre?: string; status?: string; sort?: string; cursor?: string; view?: string };
type HomeProps = { searchParams?: Promise<LegacyCatalogQuery> };

function legacyCatalogUrl(query: LegacyCatalogQuery) {
  const params = new URLSearchParams();
  for (const key of ["q", "genre", "status", "sort", "cursor"] as const) {
    const value = query[key];
    if (value) params.set(key, value);
  }
  const suffix = params.toString();
  return suffix ? `/catalog?${suffix}` : "/catalog";
}

export default async function Home({ searchParams }: HomeProps) {
  const query = await searchParams ?? {};
  if (query.view === "catalog" || query.q || query.genre || query.status || query.sort || query.cursor) {
    redirect(legacyCatalogUrl(query));
  }

  const [seriesCatalog, genres, episodeUpdates] = await Promise.all([
    listPublishedSeries(),
    listPublishedGenres(),
    listPublishedEpisodeUpdates(24),
  ]);
  const featuredSeries = seriesCatalog[0];
  const newSeries = seriesCatalog.filter((series) => series.isNew);
  const seenSeries = new Set<string>();
  const latestSeriesUpdates = episodeUpdates.filter(({ series }) => {
    if (seenSeries.has(series.slug)) return false;
    seenSeries.add(series.slug);
    return true;
  }).slice(0, 4);

  if (!featuredSeries) {
    return <div className="site-shell"><SiteHeader /><main id="main-content" className="wrap content-wrap"><div className="empty-state"><strong>Henüz yayınlanmış seri yok.</strong><p>Studio üzerinden ilk seriyi ve bölümünü yayınla.</p></div></main><SiteFooter /></div>;
  }

  const featuredFirstEpisode = [...featuredSeries.episodes].sort((a, b) => a.number - b.number)[0];

  return (
    <div className="site-shell">
      <SiteHeader />
      <main id="main-content">
        <section className="home-directory wrap" aria-label="Seri türleri">
          <details className="home-genre-directory" open>
            <summary><span>Türler</span><small>Aç / Kapat</small></summary>
            <GenreDirectoryLinks genres={genres} className="home-genre-directory__grid" />
          </details>
        </section>
        <section className="hero wrap" aria-labelledby="featured-title">
          <div className="hero-art hero-art--generated" aria-hidden="true" />
          <div className="hero-shade" />
          <div className="hero-copy">
            <div className="pill-row"><span className="pill pill--accent">Panelya Original</span><span className="pill">{featuredSeries.status}</span><span className="pill">{featuredSeries.episodes.length} bölüm</span></div>
            <p className="section-kicker">Haftanın hikâyesi</p>
            <h1 id="featured-title">{featuredSeries.title}</h1>
            <p className="hero-lede">{featuredSeries.description}</p>
            <div className="hero-actions"><Link className="button button--primary button--large" href={`/${featuredSeries.slug}/${featuredFirstEpisode.slug}`}>▶ İlk bölümü oku</Link><Link className="button button--glass button--large" href={`/${featuredSeries.slug}`}>Seriyi incele</Link></div>
          </div>
          <div className="hero-index" aria-label="Birinci öne çıkan seri"><strong>01</strong><span>/</span><span>04</span></div>
        </section>

        <div className="wrap content-wrap home-content">
          {newSeries.length > 0 && <section id="new-series" aria-labelledby="new-title">
            <div className="section-heading"><div><p className="section-kicker">Yeni keşifler</p><h2 id="new-title">Yeni Seriler</h2><p>İlk bölümünden yakalayabileceğin taze dünyalar.</p></div><Link className="inline-link inline-link--persistent" href="/new-series">Tümünü Gör →</Link></div>
            <div className="card-grid home-card-grid">{newSeries.slice(0, 4).map((series) => <SeriesCard key={series.slug} series={series} badge="Yeni seri" />)}</div>
          </section>}
          <section aria-labelledby="recent-title">
            <div className="section-heading"><div><p className="section-kicker">Okuma akışı</p><h2 id="recent-title">Yeni Eklenen Bölümler</h2><p>Son eklenen bölümlerden okumaya hemen başla.</p></div><Link className="inline-link inline-link--persistent" href="/new-episodes">Tümünü Gör →</Link></div>
            <div className="home-update-grid">
              {latestSeriesUpdates.map(({ series, episode }) => {
                const coverStyle = series.coverImage
                  ? { backgroundImage: `url("${series.coverImage}")`, backgroundPosition: series.coverPosition ?? "center" }
                  : undefined;
                return (
                  <article className="home-update-card" key={`${series.slug}/${episode.slug}`}>
                    <Link className={`home-update-card__cover poster--${series.tone}${series.coverImage ? " poster--image" : ""}`} style={coverStyle} href={`/${series.slug}/${episode.slug}`} aria-label={`${series.title}, Bölüm ${episode.number}: ${episode.title}`}>
                      <span>Bölüm {episode.number}</span>
                    </Link>
                    <div>
                      <p>{series.genres[0]}</p>
                      <h3><Link href={`/${series.slug}`}>{series.title}</Link></h3>
                      <span>{episode.title} · {episode.readTime}</span>
                    </div>
                  </article>
                );
              })}
            </div>
          </section>
          <AdSlot placement="home-feed-01" />
          <section className="manifesto-banner" aria-label="Panelya Originals">
            <div><span className="manifesto-mark" aria-hidden="true">P</span><p className="section-kicker">Panelya Originals</p><h2>Burada hikâyeler<br />telefona göre doğar.</h2></div>
            <p>Kaydırma ritmi, sessiz anlar ve bölüm sonu kancaları tek bir dikey tuval için tasarlanır. <Link className="inline-link" href="/production-journal">İlk özgün serimizin üretim günlüğünü oku →</Link></p>
          </section>
        </div>
        <section className="home-seo wrap" aria-labelledby="home-seo-title">
          <p className="section-kicker">Türkçe dikey hikâyeler</p>
          <h2 id="home-seo-title">Webtoon ritminde özgün hikâyeler keşfet</h2>
          <div className="home-seo__grid">
            <p>Panelya; romantizm, gizem, bilim kurgu, dram, komedi ve daha birçok türde özgün Türkçe dikey çizgi hikâyelerini tek katalogda buluşturur. Bir seri seçip kayıt olmadan okumaya başlayabilirsin.</p>
            <p>Bölümler telefon, tablet ve bilgisayarda kesintisiz dikey kaydırma için hazırlanır. Hesap oluşturduğunda favorilerini kütüphanende tutabilir, okuma ilerlemeni koruyabilir ve yeni bölümleri takip edebilirsin.</p>
            <p>Panelya Originals içerikleri mobil ekran ritmi, erişilebilir metinler ve bölüm sonu kancaları düşünülerek üretilir. <Link href="/publishing-principles">Yayın ilkelerimizi incele</Link> veya <Link href="/catalog">tüm serileri keşfet</Link>.</p>
          </div>
        </section>
      </main>
      <SiteFooter />
    </div>
  );
}
