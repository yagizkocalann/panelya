import Link from "next/link";
import { redirect } from "next/navigation";
import { SeriesCard } from "../components/SeriesCard";
import { SiteFooter } from "../components/SiteFooter";
import { SiteHeader } from "../components/SiteHeader";
import { getCurrentUser } from "../lib/auth";
import { listPublishedSeries } from "../lib/content-repository";
import { getDatabase } from "../lib/database";

export const dynamic = "force-dynamic";

type LibraryRow = { series_slug: string; status: string; is_favorite: number };
type ProgressRow = { series_slug: string; episode_slug: string; episode_number: number; episode_title: string; percent: number };
const statusLabels: Record<string, string> = { plan: "Okuyacağım", reading: "Okuyorum", completed: "Tamamlandı", paused: "Ara verdim", dropped: "Bıraktım" };

export default async function LibraryPage() {
  const user = await getCurrentUser();
  if (!user) redirect("/login?return_to=/library");
  const db = await getDatabase();
  const [library, progress, seriesCatalog] = await Promise.all([
    db.prepare("SELECT series_slug, status, is_favorite FROM library_items WHERE user_id = ? ORDER BY updated_at DESC").bind(user.id).all<LibraryRow>(),
    db.prepare("SELECT series_slug, episode_slug, episode_number, episode_title, percent FROM reading_progress WHERE user_id = ? ORDER BY updated_at DESC").bind(user.id).all<ProgressRow>(),
    listPublishedSeries(),
  ]);
  const seriesBySlug = new Map(seriesCatalog.map((series) => [series.slug, series]));
  const items = library.results.map((row) => ({ row, series: seriesBySlug.get(row.series_slug) })).filter((item) => item.series);
  return <div className="site-shell"><SiteHeader />
    <main id="main-content" className="dashboard-main wrap">
      <div className="page-heading"><p className="section-kicker">{user.displayName}</p><h1>Kütüphanem</h1><p>Favorilerini, okuma durumunu ve kaldığın yeri tek yerde yönet.</p></div>
      {progress.results.length > 0 && <section className="continue-grid" aria-labelledby="continue-title"><h2 id="continue-title">Okumaya devam et</h2><div className="continue-list">{progress.results.map((row) => { const series = seriesBySlug.get(row.series_slug); return series ? <Link key={row.series_slug} className="continue-card" href={`/${row.series_slug}/${row.episode_slug}`}><span>{row.percent}%</span><div><strong>{series.title}</strong><small>Bölüm {row.episode_number}: {row.episode_title}</small></div></Link> : null; })}</div></section>}
      <section className="library-section" aria-labelledby="library-title"><div className="section-heading"><div><h2 id="library-title">Kayıtlı seriler</h2><p>{items.length} seri</p></div></div>
        {items.length ? <div className="library-grid">{items.map(({ row, series }) => series && <article className="library-item" key={row.series_slug}><SeriesCard series={series} badge={row.is_favorite ? "Favori" : undefined} /><div className="library-controls">
          <form action={`/api/library/${row.series_slug}`} method="post"><input type="hidden" name="action" value="status" /><input type="hidden" name="return_to" value="/library" /><label><span className="sr-only">Okuma durumu</span><select name="status" defaultValue={row.status}>{Object.entries(statusLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label><button className="button button--ghost" type="submit">Güncelle</button></form>
          <form action={`/api/library/${row.series_slug}`} method="post"><input type="hidden" name="action" value="favorite" /><input type="hidden" name="return_to" value="/library" /><button className="button button--ghost" type="submit">{row.is_favorite ? "Favoriden çıkar" : "Favori yap"}</button></form>
          <form action={`/api/library/${row.series_slug}`} method="post"><input type="hidden" name="action" value="remove" /><input type="hidden" name="return_to" value="/library" /><button className="button button--danger" type="submit">Kaldır</button></form>
        </div></article>)}</div> : <div className="empty-state"><strong>Kütüphanen henüz boş.</strong><p>Bir seri sayfasındaki “Kütüphaneye ekle” düğmesini kullan.</p><Link className="button button--primary" href="/">Serileri keşfet</Link></div>}
      </section>
    </main><SiteFooter /></div>;
}
