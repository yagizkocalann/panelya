import type { Metadata } from "next";
import Link from "next/link";
import { SeriesCard } from "../components/SeriesCard";
import { SiteFooter } from "../components/SiteFooter";
import { SiteHeader } from "../components/SiteHeader";
import { listPublishedSeries } from "../lib/content-repository";

export const metadata: Metadata = {
  title: "Yeni Seriler — Panelya",
  description: "Panelya'da son 30 gün içinde ilk kez yayınlanan yeni dikey çizgi hikâyelerini keşfet.",
  alternates: { canonical: "/new-series" },
  openGraph: {
    title: "Yeni Seriler — Panelya",
    description: "Panelya'da son 30 gün içinde ilk kez yayınlanan yeni dikey çizgi hikâyelerini keşfet.",
    url: "/new-series",
  },
};

export default async function NewSeriesPage() {
  const newSeries = (await listPublishedSeries()).filter((series) => series.isNew);
  return (
    <div className="site-shell">
      <SiteHeader />
      <main id="main-content" className="wrap content-wrap route-page">
        <section aria-labelledby="new-series-title">
          <div className="section-heading"><div><p className="section-kicker">Yeni keşifler</p><h1 id="new-series-title">Yeni Seriler</h1><p>İlk kez son 30 gün içinde yayınlanan hikâyeler.</p></div><Link className="inline-link" href="/catalog">Tüm Seriler →</Link></div>
          {newSeries.length ? <div className="card-grid">{newSeries.map((series) => <SeriesCard key={series.slug} series={series} badge="Yeni seri" />)}</div> : <div className="empty-state"><strong>Şu anda yeni seri yok.</strong><p>Yeni bir hikâye ilk kez yayınlandığında 30 gün boyunca burada görünür.</p><Link className="button button--primary" href="/catalog">Kataloğu keşfet</Link></div>}
        </section>
      </main>
      <SiteFooter />
    </div>
  );
}
