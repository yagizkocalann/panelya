import Link from "next/link";
import Image from "next/image";
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
    <section className="studio-section" aria-labelledby="panel-manager-title">
      <div className="section-heading"><div><p className="section-kicker">Panel manifesti</p><h2 id="panel-manager-title">Sıralama ve bağlantılar</h2></div><span className="sort-note">{episode.panels.length} panel</span></div>
      <p className="studio-inline-note">Sıralama bütün panellerde değiştirilebilir. Kaldırma yalnız Studio medya hattından yüklenen panellerde açılır; R2 kaynağı silinmez ve medya envanterinde kalır.</p>
      <div className="panel-manager-list">
        {episode.panels.map((panel, index) => {
          const returnTo = `/content/${series.slug}/episodes/${episode.slug}`;
          const removable = Boolean(panel.image?.src.startsWith("/api/media/")) && episode.panels.length > 1;
          return <article className="panel-manager-card" key={panel.id}>
            <div className="panel-manager-card__preview">{panel.image ? <Image src={panel.image.src} alt={panel.image.alt} width={panel.image.width} height={panel.image.height} unoptimized /> : <span>{String(index + 1).padStart(2, "0")}</span>}</div>
            <div className="panel-manager-card__copy"><strong>{index + 1}. {panel.caption || panel.dialogue || panel.scene}</strong><small>{panel.id} · {panel.tone}{panel.image ? ` · ${panel.image.width} × ${panel.image.height}` : " · metin paneli"}</small></div>
            <div className="panel-manager-card__actions">
              {index > 0 && <form action="/api/admin/media/manage" method="post"><input type="hidden" name="action" value="panel_move" /><input type="hidden" name="direction" value="up" /><input type="hidden" name="series_slug" value={series.slug} /><input type="hidden" name="episode_slug" value={episode.slug} /><input type="hidden" name="panel_id" value={panel.id} /><input type="hidden" name="return_to" value={returnTo} /><button className="button button--ghost" type="submit" aria-label={`${index + 1}. paneli yukarı taşı`}>↑</button></form>}
              {index < episode.panels.length - 1 && <form action="/api/admin/media/manage" method="post"><input type="hidden" name="action" value="panel_move" /><input type="hidden" name="direction" value="down" /><input type="hidden" name="series_slug" value={series.slug} /><input type="hidden" name="episode_slug" value={episode.slug} /><input type="hidden" name="panel_id" value={panel.id} /><input type="hidden" name="return_to" value={returnTo} /><button className="button button--ghost" type="submit" aria-label={`${index + 1}. paneli aşağı taşı`}>↓</button></form>}
              {removable && <form action="/api/admin/media/manage" method="post"><input type="hidden" name="action" value="panel_remove" /><input type="hidden" name="series_slug" value={series.slug} /><input type="hidden" name="episode_slug" value={episode.slug} /><input type="hidden" name="panel_id" value={panel.id} /><input type="hidden" name="return_to" value={returnTo} /><button className="button button--danger" type="submit">Bağlantıyı kaldır</button></form>}
            </div>
          </article>;
        })}
      </div>
    </section>
  </main></div>;
}
