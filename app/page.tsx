import type { Metadata } from "next";
import Link from "next/link";
import { SeriesCard } from "./components/SeriesCard";
import { SiteFooter } from "./components/SiteFooter";
import { SiteHeader } from "./components/SiteHeader";
import { AdTestSlot } from "./components/AdTestSlot";
import { genresFromSeries, listPublishedSeries } from "./lib/content-repository";

export const metadata: Metadata = {
  title: "Panelya — Kaydır, keşfet, hikâyeye gir",
  description: "Özgün Türkçe dikey çizgi hikâyeleri keşfet ve ücretsiz oku.",
};

type HomeProps = { searchParams?: Promise<{ q?: string; genre?: string }> };

export default async function Home({ searchParams }: HomeProps) {
  const [query, seriesCatalog] = await Promise.all([searchParams, listPublishedSeries()]);
  const featuredSeries = seriesCatalog[0];
  const search = query?.q?.trim().toLocaleLowerCase("tr") ?? "";
  const genre = query?.genre?.trim() ?? "";
  const filtered = seriesCatalog.filter((series) => {
    const matchesSearch = !search || `${series.title} ${series.creator} ${series.genres.join(" ")}`.toLocaleLowerCase("tr").includes(search);
    return matchesSearch && (!genre || series.genres.includes(genre));
  });
  const isFiltered = Boolean(search || genre);

  if (!featuredSeries) return <div className="site-shell"><SiteHeader /><main id="main-content" className="wrap content-wrap"><div className="empty-state"><strong>Henüz yayınlanmış seri yok.</strong><p>Studio üzerinden ilk seriyi ve bölümünü yayınla.</p></div></main><SiteFooter /></div>;
  const featuredFirstEpisode = [...featuredSeries.episodes].sort((a, b) => a.number - b.number)[0];

  return (
    <div className="site-shell">
      <SiteHeader />
      <main id="main-content">
        {!isFiltered && (
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
        )}

        <div className="wrap content-wrap">
          {isFiltered ? (
            <section className="catalog-results" aria-labelledby="results-title">
              <div className="section-heading"><div><p className="section-kicker">Arama sonuçları</p><h1 id="results-title">{genre || (search ? `“${query?.q}”` : "Tüm seriler")}</h1></div><Link className="inline-link" href="/">Filtreleri temizle</Link></div>
              {filtered.length ? <div className="card-grid">{filtered.map((series) => <SeriesCard key={series.slug} series={series} />)}</div> : <div className="empty-state"><strong>Bu rotada henüz bir hikâye yok.</strong><p>Başka bir ad veya tür deneyebilirsin.</p><Link className="button button--primary" href="/">Keşfe dön</Link></div>}
            </section>
          ) : (
            <>
              <section className="genre-strip" aria-label="Türlere göre keşfet">
                <span>Hızlı keşif</span>{genresFromSeries(seriesCatalog).slice(0, 8).map((item) => <Link key={item} href={`/?genre=${encodeURIComponent(item)}`}>{item}</Link>)}
              </section>
              <section aria-labelledby="recent-title">
                <div className="section-heading"><div><p className="section-kicker">Okuma akışı</p><h2 id="recent-title">Yeni bölüm eklenenler</h2><p>Hikâyeye kaldığın yerden değil, merak ettiğin yerden gir.</p></div><Link className="inline-link" href="/?genre=Dram">Tümünü gör →</Link></div>
                <div className="card-grid">{seriesCatalog.slice(0, 4).map((series, index) => <SeriesCard key={series.slug} series={series} badge={index === 0 ? "Yeni bölüm" : undefined} />)}</div>
              </section>
              <AdTestSlot placement="home-feed-01" />
              <section className="manifesto-banner" aria-label="Panelya Originals">
                <div><span className="manifesto-mark" aria-hidden="true">P</span><p className="section-kicker">Panelya Originals</p><h2>Burada hikâyeler<br />telefona göre doğar.</h2></div>
                <p>Kaydırma ritmi, sessiz anlar ve bölüm sonu kancaları tek bir dikey tuval için tasarlanır. <Link className="inline-link" href="/production-journal">İlk özgün serimizin üretim günlüğünü oku →</Link></p>
              </section>
              <section id="new-series" aria-labelledby="new-title">
                <div className="section-heading"><div><p className="section-kicker">Yeni keşifler</p><h2 id="new-title">Yeni seriler</h2><p>İlk bölümünden yakalayabileceğin taze dünyalar.</p></div></div>
                <div className="card-grid card-grid--three">{seriesCatalog.filter((series) => series.isNew).map((series) => <SeriesCard key={series.slug} series={series} badge="Yeni seri" />)}</div>
              </section>
            </>
          )}
        </div>
      </main>
      <SiteFooter />
    </div>
  );
}
