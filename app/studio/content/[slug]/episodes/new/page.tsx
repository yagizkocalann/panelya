import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { SiteHeader } from "../../../../../components/SiteHeader";
import { getCurrentUser } from "../../../../../lib/auth";
import { getStudioSeries } from "../../../../../lib/content-repository";
import { assessEpisodePublishing } from "../../../../../lib/publishing-readiness";
import { publicSiteUrlForCurrentRequest } from "../../../../../lib/server-site-origins";
import { EpisodeForm } from "../../../ContentForms";
import { PublishingReadinessSummary } from "../../../PublishingReadiness";

export const dynamic = "force-dynamic";

export default async function NewEpisodePage({ params, searchParams }: { params: Promise<{ slug: string }>; searchParams: Promise<{ error?: string }> }) {
  const user = await getCurrentUser();
  if (!user) redirect("/login?return_to=/content");
  if (user.role !== "admin") redirect("/account?error=Studio%20yalnızca%20yönetici%20hesaplarına%20açık.");
  const [{ slug }, query, publicHome] = await Promise.all([params, searchParams, publicSiteUrlForCurrentRequest("/")]);
  const series = await getStudioSeries(slug);
  if (!series) notFound();
  return <div className="site-shell studio-shell"><SiteHeader compact homeHref={publicHome} /><main id="main-content" className="studio-main wrap">
    <div className="studio-top"><div><p className="section-kicker">{series.title}</p><h1>Yeni bölüm oluştur</h1><p>Bölüm bilgisini ve ilk yerel anlatı panelini hazırla.</p></div><Link className="button button--ghost" href={`/content/${series.slug}`}>← Seriye dön</Link></div>
    {query.error && <p className="form-message form-message--error" role="alert">{query.error}</p>}
    <PublishingReadinessSummary readiness={assessEpisodePublishing({ title: "", publishedAt: "", readTime: "", panels: [], seriesPublicationStatus: series.publicationStatus })} title="Yeni bölüm yayın kontrolü" />
    <EpisodeForm series={series} />
  </main></div>;
}
