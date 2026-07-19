import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { SiteHeader } from "../../../components/SiteHeader";
import { getCurrentUser } from "../../../lib/auth";
import { getStudioSeries } from "../../../lib/content-repository";
import { listPreviewGrants } from "../../../lib/preview-tokens";
import { assessSeriesPublishing } from "../../../lib/publishing-readiness";
import { publicSiteUrlForCurrentRequest } from "../../../lib/server-site-origins";
import { SeriesForm } from "../ContentForms";
import { PreviewAccessPanel, PreviewCreateForm } from "../PreviewAccess";
import { PublishingReadinessSummary } from "../PublishingReadiness";

export const dynamic = "force-dynamic";

export default async function EditSeriesPage({ params, searchParams }: { params: Promise<{ slug: string }>; searchParams: Promise<{ error?: string; saved?: string; created?: string; preview?: string }> }) {
  const user = await getCurrentUser();
  if (!user) redirect("/login?return_to=/content");
  if (user.role !== "admin") redirect("/account?error=Studio%20yalnızca%20yönetici%20hesaplarına%20açık.");
  const [{ slug }, query, publicHome] = await Promise.all([params, searchParams, publicSiteUrlForCurrentRequest("/")]);
  const series = await getStudioSeries(slug);
  if (!series) notFound();
  const returnTo = `/content/${series.slug}`;
  const previewGrants = await listPreviewGrants(series.slug, null);
  return <div className="site-shell studio-shell"><SiteHeader compact homeHref={publicHome} /><main id="main-content" className="studio-main wrap">
    <div className="studio-top"><div><p className="section-kicker">İçerik · {series.publicationStatus === "published" ? "yayında" : series.publicationStatus === "draft" ? "taslak" : "arşiv"}</p><h1>{series.title}</h1><p>Seri bilgilerini ve yayın durumunu yönet.</p></div><div className="studio-top__actions"><Link className="button button--ghost" href="/content">← İçerik</Link>{series.publicationStatus === "published" && <Link className="button button--ghost" href={new URL(`/${series.slug}`, publicHome).toString()}>Public sayfa ↗</Link>}<PreviewCreateForm seriesSlug={series.slug} returnTo={returnTo} /></div></div>
    {(query.saved || query.created) && <p className="form-message form-message--success" role="status">{query.created ? "Taslak seri oluşturuldu." : "Seri değişiklikleri kaydedildi."}</p>}
    {query.preview === "revoked" && <p className="form-message form-message--success" role="status">Önizleme bağlantısı iptal edildi.</p>}
    {query.error && <p className="form-message form-message--error" role="alert">{query.error}</p>}
    <PublishingReadinessSummary readiness={assessSeriesPublishing(series)} title="Seri yayın kontrolü" />
    <SeriesForm series={series} />
    <section className="studio-section"><div className="section-heading"><div><p className="section-kicker">Bölüm yönetimi</p><h2>Bölümler</h2></div><Link className="button button--primary" href={`/content/${series.slug}/episodes/new`}>＋ Yeni bölüm</Link></div>
      {series.episodes.length ? <div className="studio-episode-list">{[...series.episodes].sort((a, b) => b.number - a.number).map((episode) => <article key={episode.id}><div><span className={`pill${episode.publicationStatus === "published" ? " pill--accent" : ""}`}>{episode.publicationStatus === "published" ? "Yayında" : episode.publicationStatus === "draft" ? "Taslak" : "Arşiv"}</span><strong>Bölüm {episode.number}: {episode.title}</strong><small>{episode.panels.length} panel · {episode.readTime}</small></div><Link className="button button--ghost" href={`/content/${series.slug}/episodes/${episode.slug}`}>Düzenle</Link></article>)}</div> : <div className="empty-state"><strong>Henüz bölüm yok.</strong><p>Seriyi yayınlayabilmek için en az bir yayınlanmış bölüm oluştur.</p><Link className="button button--primary" href={`/content/${series.slug}/episodes/new`}>İlk bölümü oluştur</Link></div>}
    </section>
    <PreviewAccessPanel grants={previewGrants} seriesSlug={series.slug} returnTo={returnTo} />
  </main></div>;
}
