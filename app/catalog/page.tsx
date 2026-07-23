import type { Metadata } from "next";
import Link from "next/link";
import { SeriesCard } from "../components/SeriesCard";
import { SiteFooter } from "../components/SiteFooter";
import { SiteHeader } from "../components/SiteHeader";
import { listPublishedGenres, searchPublishedSeriesPage, type CatalogPageResult } from "../lib/content-repository";
import { CatalogFilterForm } from "./CatalogFilterForm";

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

type CatalogQuery = { q?: string; genre?: string; status?: string; sort?: string; page?: string; size?: string };
type CatalogProps = { searchParams?: Promise<CatalogQuery> };

function catalogUrl(filters: CatalogPageResult["filters"], page = 1, pageSize = 8) {
  const params = new URLSearchParams();
  if (filters.query) params.set("q", filters.query);
  if (filters.genre) params.set("genre", filters.genre);
  if (filters.status) params.set("status", filters.status);
  if (filters.sort !== "updated") params.set("sort", filters.sort);
  if (pageSize !== 8) params.set("size", String(pageSize));
  if (page > 1) params.set("page", String(page));
  const suffix = params.toString();
  return suffix ? `/catalog?${suffix}` : "/catalog";
}

function visiblePages(currentPage: number, totalPages: number) {
  const pages = new Set([1, totalPages, currentPage - 1, currentPage, currentPage + 1]);
  const validPages = Array.from(pages).filter((page) => page >= 1 && page <= totalPages).sort((a, b) => a - b);
  const result: Array<number | "ellipsis"> = [];
  for (const page of validPages) {
    const previous = result.at(-1);
    if (typeof previous === "number" && page - previous > 1) result.push("ellipsis");
    result.push(page);
  }
  return result;
}

export default async function CatalogPage({ searchParams }: CatalogProps) {
  const query = await searchParams ?? {};
  const requestedPage = Number.parseInt(query.page ?? "1", 10);
  const requestedSize = Number.parseInt(query.size ?? "8", 10);
  const [genres, catalogResult] = await Promise.all([
    listPublishedGenres(),
    searchPublishedSeriesPage({
      query: query.q,
      genre: query.genre,
      status: query.status,
      sort: query.sort,
      page: Number.isFinite(requestedPage) ? requestedPage : 1,
      pageSize: requestedSize,
    }),
  ]);
  const { items, filters } = catalogResult;
  const hasActiveFilters = Boolean(filters.query || filters.genre || filters.status || filters.sort !== "updated");
  const firstResult = catalogResult.totalItems ? (catalogResult.page - 1) * catalogResult.pageSize + 1 : 0;
  const lastResult = Math.min(catalogResult.page * catalogResult.pageSize, catalogResult.totalItems);

  return (
    <div className="site-shell">
      <SiteHeader />
      <main id="main-content" className="wrap content-wrap route-page">
        <section className="catalog-results" aria-labelledby="results-title">
          <div className="section-heading"><div><p className="section-kicker">Katalog keşfi</p><h1 id="results-title">{filters.genre || (filters.query ? `“${filters.query}”` : "Tüm seriler")}</h1><p>Yayınlanmış hikâyeleri ada, üreticiye, türe ve yayın durumuna göre keşfet.</p></div>{hasActiveFilters && <Link className="inline-link" href="/catalog">Filtreleri temizle</Link>}</div>
          <CatalogFilterForm genres={genres} filters={filters} pageSize={catalogResult.pageSize} />
          {items.length ? <>
            <div className="catalog-result-meta" aria-live="polite"><span>{catalogResult.totalItems} seriden {firstResult}–{lastResult} arası</span><span>{filters.sort === "rating" ? "Puana göre" : filters.sort === "title" ? "Ada göre" : "Son güncellenen"}</span></div>
            <div className="card-grid">{items.map((series) => <SeriesCard key={series.slug} series={series} />)}</div>
            <div className="catalog-navigation">
              <nav className="catalog-page-size" aria-label="Sayfa başına seri sayısı"><span>Sayfa başına</span>{([8, 16, 32] as const).map((size) => <Link key={size} className={`button button--compact${catalogResult.pageSize === size ? " is-active" : ""}`} aria-current={catalogResult.pageSize === size ? "true" : undefined} href={catalogUrl(filters, 1, size)}>{size}</Link>)}</nav>
              {catalogResult.totalPages > 1 && <nav className="catalog-pagination" aria-label="Katalog sayfaları">{visiblePages(catalogResult.page, catalogResult.totalPages).map((page, index) => page === "ellipsis" ? <span className="catalog-pagination__ellipsis" aria-hidden="true" key={`ellipsis-${index}`}>…</span> : page === catalogResult.page ? <span className="button button--primary" aria-current="page" key={page}>{page}</span> : <Link className="button button--ghost" href={catalogUrl(filters, page, catalogResult.pageSize)} key={page}>{page}</Link>)}</nav>}
            </div>
          </> : <div className="empty-state"><strong>Bu filtrelerde henüz bir hikâye yok.</strong><p>Başka bir ad, tür veya yayın durumu deneyebilirsin.</p><Link className="button button--primary" href="/catalog">Tüm serileri göster</Link></div>}
        </section>
      </main>
      <SiteFooter />
    </div>
  );
}
