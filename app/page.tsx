import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { AdSlot } from "./components/AdSlot";
import { SeriesCard } from "./components/SeriesCard";
import { SiteFooter } from "./components/SiteFooter";
import { SiteHeader } from "./components/SiteHeader";
import { listPublishedGenres, listPublishedSeries } from "./lib/content-repository";

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

  const [seriesCatalog, genres] = await Promise.all([listPublishedSeries(), listPublishedGenres()]);
  const featuredSeries = seriesCatalog[0];

  if (!featuredSeries) {
    return <div className="site-shell"><SiteHeader /><main id="main-content" className="wrap content-wrap"><div className="empty-state"><strong>Henüz yayınlanmış seri yok.</strong><p>Studio üzerinden ilk seriyi ve bölümünü yayınla.</p></div></main><SiteFooter /></div>;
  }

  const featuredFirstEpisode = [...featuredSeries.episodes].sort((a, b) => a.number - b.number)[0];

  return (
    <div className="site-shell">
      <SiteHeader />
      <main id="main-content">
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

        <div className="wrap content-wrap">
          <section className="genre-strip" aria-label="Türlere göre keşfet">
            <span>Hızlı keşif</span>{genres.slice(0, 8).map((item) => <Link key={item} href={`/catalog?genre=${encodeURIComponent(item)}`}>{item}</Link>)}
          </section>
          <section aria-labelledby="recent-title">
            <div className="section-heading"><div><p className="section-kicker">Okuma akışı</p><h2 id="recent-title">Yeni bölüm eklenenler</h2><p>Hikâyeye kaldığın yerden değil, merak ettiğin yerden gir.</p></div><Link className="inline-link" href="/updates">Tüm güncellemeleri gör →</Link></div>
            <div className="card-grid">{seriesCatalog.slice(0, 4).map((series, index) => <SeriesCard key={series.slug} series={series} badge={index === 0 ? "Yeni bölüm" : undefined} />)}</div>
          </section>
          <AdSlot placement="home-feed-01" />
          <section className="manifesto-banner" aria-label="Panelya Originals">
            <div><span className="manifesto-mark" aria-hidden="true">P</span><p className="section-kicker">Panelya Originals</p><h2>Burada hikâyeler<br />telefona göre doğar.</h2></div>
            <p>Kaydırma ritmi, sessiz anlar ve bölüm sonu kancaları tek bir dikey tuval için tasarlanır. <Link className="inline-link" href="/production-journal">İlk özgün serimizin üretim günlüğünü oku →</Link></p>
          </section>
          <section id="new-series" aria-labelledby="new-title">
            <div className="section-heading"><div><p className="section-kicker">Yeni keşifler</p><h2 id="new-title">Yeni seriler</h2><p>İlk bölümünden yakalayabileceğin taze dünyalar.</p></div></div>
            <div className="card-grid card-grid--three">{seriesCatalog.filter((series) => series.isNew).map((series) => <SeriesCard key={series.slug} series={series} badge="Yeni seri" />)}</div>
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
