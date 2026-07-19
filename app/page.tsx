import type { Metadata } from "next";
import Link from "next/link";
import { SeriesCard } from "./components/SeriesCard";
import { SiteFooter } from "./components/SiteFooter";
import { SiteHeader } from "./components/SiteHeader";
import { AdTestSlot } from "./components/AdTestSlot";
import { listPublishedGenres, listPublishedSeries, searchPublishedSeries, type CatalogSearchResult } from "./lib/content-repository";

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

type HomeQuery = { q?: string; genre?: string; status?: string; sort?: string; cursor?: string; view?: string };
type HomeProps = { searchParams?: Promise<HomeQuery> };

function catalogUrl(filters: CatalogSearchResult["filters"], cursor?: string | null) {
  const params = new URLSearchParams({ view: "catalog" });
  if (filters.query) params.set("q", filters.query);
  if (filters.genre) params.set("genre", filters.genre);
  if (filters.status) params.set("status", filters.status);
  if (filters.sort !== "updated") params.set("sort", filters.sort);
  if (cursor) params.set("cursor", cursor);
  return `/?${params.toString()}`;
}

export default async function Home({ searchParams }: HomeProps) {
  const query = await searchParams ?? {};
  const isCatalogView = Boolean(query.view === "catalog" || query.q || query.genre || query.status || query.sort || query.cursor);
  const [seriesCatalog, genres, catalogResult] = await Promise.all([
    listPublishedSeries(),
    listPublishedGenres(),
    isCatalogView ? searchPublishedSeries({
      query: query.q,
      genre: query.genre,
      status: query.status,
      sort: query.sort,
      cursor: query.cursor,
      limit: 4,
    }) : Promise.resolve(null),
  ]);
  const featuredSeries = seriesCatalog[0];
  const filtered = catalogResult?.items ?? [];
  const filters = catalogResult?.filters ?? { query: "", genre: "", status: "" as const, sort: "updated" as const };

  if (!featuredSeries) return <div className="site-shell"><SiteHeader /><main id="main-content" className="wrap content-wrap"><div className="empty-state"><strong>Henüz yayınlanmış seri yok.</strong><p>Studio üzerinden ilk seriyi ve bölümünü yayınla.</p></div></main><SiteFooter /></div>;
  const featuredFirstEpisode = [...featuredSeries.episodes].sort((a, b) => a.number - b.number)[0];

  return (
    <div className="site-shell">
      <SiteHeader />
      <main id="main-content">
        {!isCatalogView && (
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
          {isCatalogView ? (
            <section className="catalog-results" aria-labelledby="results-title">
              <div className="section-heading"><div><p className="section-kicker">Katalog keşfi</p><h1 id="results-title">{filters.genre || (filters.query ? `“${filters.query}”` : "Tüm seriler")}</h1><p>Arama D1 üzerindeki yayınlanmış serilerde çalışır; sıralama ve sayfalama aynı sonuç kümesini korur.</p></div><Link className="inline-link" href="/">Filtreleri temizle</Link></div>
              <form className="catalog-filter-form" action="/" method="get" role="search">
                <input type="hidden" name="view" value="catalog" />
                <label><span>Seri ara</span><input name="q" type="search" defaultValue={filters.query} placeholder="Başlık, üretici veya tür" maxLength={80} /></label>
                <label><span>Tür</span><select name="genre" defaultValue={filters.genre}><option value="">Tüm türler</option>{genres.map((item) => <option value={item} key={item}>{item}</option>)}</select></label>
                <label><span>Durum</span><select name="status" defaultValue={filters.status}><option value="">Tümü</option><option value="ongoing">Devam ediyor</option><option value="completed">Tamamlandı</option></select></label>
                <label><span>Sırala</span><select name="sort" defaultValue={filters.sort}><option value="updated">Son güncellenen</option><option value="rating">Puana göre</option><option value="title">Ada göre</option></select></label>
                <button className="button button--primary" type="submit">Sonuçları getir</button>
              </form>
              {catalogResult?.cursorWasInvalid && <p className="catalog-notice" role="status">Geçersiz veya eski sayfa bağlantısı yok sayıldı; ilk sonuçlar gösteriliyor.</p>}
              {filtered.length ? <><div className="catalog-result-meta" aria-live="polite"><span>Bu sayfada {filtered.length} seri</span><span>{filters.sort === "rating" ? "Puana göre" : filters.sort === "title" ? "Ada göre" : "Son güncellenen"}</span></div><div className="card-grid">{filtered.map((series) => <SeriesCard key={series.slug} series={series} />)}</div><nav className="catalog-pagination" aria-label="Katalog sayfaları">{query.cursor && <Link className="button button--ghost" href={catalogUrl(filters)}>İlk sayfa</Link>}{catalogResult?.nextCursor && <Link className="button button--primary" href={catalogUrl(filters, catalogResult.nextCursor)}>Sonraki sonuçlar →</Link>}</nav></> : <div className="empty-state"><strong>Bu filtrelerde henüz bir hikâye yok.</strong><p>Başka bir ad, tür veya yayın durumu deneyebilirsin.</p><Link className="button button--primary" href="/?view=catalog">Tüm serileri göster</Link></div>}
            </section>
          ) : (
            <>
              <section className="genre-strip" aria-label="Türlere göre keşfet">
                <span>Hızlı keşif</span>{genres.slice(0, 8).map((item) => <Link key={item} href={`/?genre=${encodeURIComponent(item)}`}>{item}</Link>)}
              </section>
              <section aria-labelledby="recent-title">
                <div className="section-heading"><div><p className="section-kicker">Okuma akışı</p><h2 id="recent-title">Yeni bölüm eklenenler</h2><p>Hikâyeye kaldığın yerden değil, merak ettiğin yerden gir.</p></div><Link className="inline-link" href="/?view=catalog">Tüm kataloğu keşfet →</Link></div>
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
