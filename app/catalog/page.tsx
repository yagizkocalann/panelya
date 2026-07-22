import type { Metadata } from "next";
import Link from "next/link";
import { SeriesCard } from "../components/SeriesCard";
import { SiteFooter } from "../components/SiteFooter";
import { SiteHeader } from "../components/SiteHeader";
import { listPublishedGenres, searchPublishedSeries, type CatalogSearchResult } from "../lib/content-repository";

export const metadata: Metadata = {
  title: "Tüm seriler — Panelya",
  description: "Panelya'daki yayınlanmış Türkçe dikey çizgi hikâyelerini ara, filtrele ve keşfet.",
  alternates: { canonical: "/catalog" },
  openGraph: {
    title: "Tüm seriler — Panelya",
    description: "Panelya'daki yayınlanmış Türkçe dikey çizgi hikâyelerini ara, filtrele ve keşfet.",
    url: "/catalog",
  },
};

type CatalogQuery = { q?: string; genre?: string; status?: string; sort?: string; cursor?: string };
type CatalogProps = { searchParams?: Promise<CatalogQuery> };

function catalogUrl(filters: CatalogSearchResult["filters"], cursor?: string | null) {
  const params = new URLSearchParams();
  if (filters.query) params.set("q", filters.query);
  if (filters.genre) params.set("genre", filters.genre);
  if (filters.status) params.set("status", filters.status);
  if (filters.sort !== "updated") params.set("sort", filters.sort);
  if (cursor) params.set("cursor", cursor);
  const suffix = params.toString();
  return suffix ? `/catalog?${suffix}` : "/catalog";
}

export default async function CatalogPage({ searchParams }: CatalogProps) {
  const query = await searchParams ?? {};
  const [genres, catalogResult] = await Promise.all([
    listPublishedGenres(),
    searchPublishedSeries({
      query: query.q,
      genre: query.genre,
      status: query.status,
      sort: query.sort,
      cursor: query.cursor,
      limit: 4,
    }),
  ]);
  const { items, filters } = catalogResult;

  return (
    <div className="site-shell">
      <SiteHeader />
      <main id="main-content" className="wrap content-wrap route-page">
        <section className="catalog-results" aria-labelledby="results-title">
          <div className="section-heading"><div><p className="section-kicker">Katalog keşfi</p><h1 id="results-title">{filters.genre || (filters.query ? `“${filters.query}”` : "Tüm seriler")}</h1><p>Yayınlanmış hikâyeleri ada, üreticiye, türe ve yayın durumuna göre keşfet.</p></div><Link className="inline-link" href="/catalog">Filtreleri temizle</Link></div>
          <form className="catalog-filter-form" action="/catalog" method="get" role="search">
            <label><span>Seri ara</span><input name="q" type="search" defaultValue={filters.query} placeholder="Başlık, üretici veya tür" maxLength={80} /></label>
            <label><span>Tür</span><select name="genre" defaultValue={filters.genre}><option value="">Tüm türler</option>{genres.map((item) => <option value={item} key={item}>{item}</option>)}</select></label>
            <label><span>Durum</span><select name="status" defaultValue={filters.status}><option value="">Tümü</option><option value="ongoing">Devam ediyor</option><option value="completed">Tamamlandı</option></select></label>
            <label><span>Sırala</span><select name="sort" defaultValue={filters.sort}><option value="updated">Son güncellenen</option><option value="rating">Puana göre</option><option value="title">Ada göre</option></select></label>
            <button className="button button--primary" type="submit">Sonuçları getir</button>
          </form>
          {catalogResult.cursorWasInvalid && <p className="catalog-notice" role="status">Geçersiz veya eski sayfa bağlantısı yok sayıldı; ilk sonuçlar gösteriliyor.</p>}
          {items.length ? <><div className="catalog-result-meta" aria-live="polite"><span>Bu sayfada {items.length} seri</span><span>{filters.sort === "rating" ? "Puana göre" : filters.sort === "title" ? "Ada göre" : "Son güncellenen"}</span></div><div className="card-grid">{items.map((series) => <SeriesCard key={series.slug} series={series} />)}</div><nav className="catalog-pagination" aria-label="Katalog sayfaları">{query.cursor && <Link className="button button--ghost" href={catalogUrl(filters)}>İlk sayfa</Link>}{catalogResult.nextCursor && <Link className="button button--primary" href={catalogUrl(filters, catalogResult.nextCursor)}>Sonraki sonuçlar →</Link>}</nav></> : <div className="empty-state"><strong>Bu filtrelerde henüz bir hikâye yok.</strong><p>Başka bir ad, tür veya yayın durumu deneyebilirsin.</p><Link className="button button--primary" href="/catalog">Tüm serileri göster</Link></div>}
        </section>
      </main>
      <SiteFooter />
    </div>
  );
}
