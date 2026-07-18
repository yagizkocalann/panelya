import Link from "next/link";
import { redirect } from "next/navigation";
import { SiteHeader } from "../../components/SiteHeader";
import { getCurrentUser } from "../../lib/auth";
import { listStudioSeries } from "../../lib/content-repository";
import { publicSiteUrlForCurrentRequest } from "../../lib/server-site-origins";

export const dynamic = "force-dynamic";

const statusLabels = { draft: "Taslak", published: "Yayında", archived: "Arşiv" } as const;

export default async function StudioContentPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const user = await getCurrentUser();
  if (!user) redirect("/login?return_to=/content");
  if (user.role !== "admin") redirect("/account?error=Studio%20yalnızca%20yönetici%20hesaplarına%20açık.");
  const [seriesCatalog, publicHome, query] = await Promise.all([listStudioSeries(), publicSiteUrlForCurrentRequest("/"), searchParams]);
  return <div className="site-shell studio-shell"><SiteHeader compact homeHref={publicHome} /><main id="main-content" className="studio-main wrap">
    <div className="studio-top"><div><p className="section-kicker">İçerik</p><h1>Seri ve bölümler</h1><p>Taslakları hazırla, bölümleri düzenle ve tamamlanan içeriği public kataloğa yayınla.</p></div><div className="studio-top__actions"><Link className="button button--ghost" href="/">← Studio</Link><Link className="button button--primary" href="/content/new">＋ Yeni seri</Link></div></div>
    <aside className="studio-notice"><strong>D1 içerik kaynağı:</strong> Bu ekrandaki değişiklikler kalıcıdır. Yalnızca “Yayında” durumundaki ve yayınlanmış bölümü bulunan seriler public sitede görünür.</aside>
    {query.error && <p className="form-message form-message--error" role="alert">{query.error}</p>}
    <div className="content-inventory">{seriesCatalog.map((series) => <section className="inventory-card" key={series.slug}><header><div><div className="inventory-status"><span className={`pill${series.publicationStatus === "published" ? " pill--accent" : ""}`}>{statusLabels[series.publicationStatus]}</span>{series.isFeatured && <span className="pill">Öne çıkan</span>}</div><h2>{series.title}</h2><span>{series.creator} · {series.genres.join(" · ")}</span></div><Link className="button button--primary" href={`/content/${series.slug}`}>Yönet</Link></header><ol>{[...series.episodes].sort((a, b) => a.number - b.number).map((episode) => <li key={episode.id}><div><strong>Bölüm {episode.number}: {episode.title}</strong><small>{statusLabels[episode.publicationStatus]} · {episode.readTime} · {episode.panels.length} panel</small></div><Link href={`/content/${series.slug}/episodes/${episode.slug}`}>Düzenle →</Link></li>)}</ol>{!series.episodes.length && <div className="inventory-empty"><span>Henüz bölüm yok.</span><Link href={`/content/${series.slug}/episodes/new`}>İlk bölümü oluştur →</Link></div>}</section>)}</div>
  </main></div>;
}
