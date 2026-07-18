import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { SiteHeader } from "../../../../../components/SiteHeader";
import { getCurrentUser } from "../../../../../lib/auth";
import { getStudioSeries } from "../../../../../lib/content-repository";
import { publicSiteUrlForCurrentRequest } from "../../../../../lib/server-site-origins";
import { EpisodeForm } from "../../../ContentForms";

export const dynamic = "force-dynamic";

export default async function EditEpisodePage({ params, searchParams }: { params: Promise<{ slug: string; episode: string }>; searchParams: Promise<{ error?: string; saved?: string }> }) {
  const user = await getCurrentUser();
  if (!user) redirect("/login?return_to=/content");
  if (user.role !== "admin") redirect("/account?error=Studio%20yalnızca%20yönetici%20hesaplarına%20açık.");
  const [{ slug, episode: episodeSlug }, query, publicHome] = await Promise.all([params, searchParams, publicSiteUrlForCurrentRequest("/")]);
  const series = await getStudioSeries(slug);
  const episode = series?.episodes.find((item) => item.slug === episodeSlug);
  if (!series || !episode) notFound();
  return <div className="site-shell studio-shell"><SiteHeader compact homeHref={publicHome} /><main id="main-content" className="studio-main wrap">
    <div className="studio-top"><div><p className="section-kicker">{series.title} · Bölüm {episode.number}</p><h1>{episode.title}</h1><p>Bölüm metadatasını ve uygun olduğunda yerel panel metnini düzenle.</p></div><div className="studio-top__actions"><Link className="button button--ghost" href={`/content/${series.slug}`}>← Seriye dön</Link>{series.publicationStatus === "published" && episode.publicationStatus === "published" && <Link className="button button--ghost" href={new URL(`/${series.slug}/${episode.slug}`, publicHome).toString()}>Okuyucu ↗</Link>}</div></div>
    {query.saved && <p className="form-message form-message--success" role="status">Bölüm kaydedildi.</p>}
    {query.error && <p className="form-message form-message--error" role="alert">{query.error}</p>}
    <EpisodeForm series={series} episode={episode} />
  </main></div>;
}
