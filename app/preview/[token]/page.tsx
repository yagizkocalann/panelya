import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import type { Episode } from "../../data/catalog";
import { getAdjacentEpisodes } from "../../data/catalog";
import { ReaderExperience } from "../../[slug]/[episode]/ReaderExperience";
import { getStudioSeries } from "../../lib/content-repository";
import { writeAudit } from "../../lib/database";
import { resolvePreviewGrant } from "../../lib/preview-tokens";

export const dynamic = "force-dynamic";
export const revalidate = 0;
export const metadata: Metadata = {
  title: "Taslak önizleme — Panelya",
  robots: { index: false, follow: false, noarchive: true, nosnippet: true },
  referrer: "no-referrer",
};

function protectedMediaUrl(src: string | undefined, token: string) {
  const match = src?.match(/^\/api\/media\/([A-Za-z0-9-]+)$/);
  return match ? `/api/preview/media/${match[1]}?token=${encodeURIComponent(token)}` : src;
}

function protectedEpisode(episode: Episode, token: string): Episode {
  return {
    ...episode,
    panels: episode.panels.map((panel) => panel.image ? {
      ...panel,
      image: { ...panel.image, src: protectedMediaUrl(panel.image.src, token) ?? panel.image.src },
    } : panel),
  };
}

export default async function PreviewPage({
  params,
  searchParams,
}: {
  params: Promise<{ token: string }>;
  searchParams: Promise<{ episode?: string; index?: string }>;
}) {
  const [{ token }, query] = await Promise.all([params, searchParams]);
  const grant = await resolvePreviewGrant(token);
  if (!grant) notFound();
  const series = await getStudioSeries(grant.seriesSlug);
  if (!series) notFound();

  const requestedEpisode = query.index === "1" ? undefined : grant.episodeSlug ?? query.episode;
  const episode = requestedEpisode ? series.episodes.find((item) => item.slug === requestedEpisode) : undefined;
  if (requestedEpisode && !episode) notFound();
  await writeAudit(null, "preview.opened", { grantId: grant.id, seriesSlug: grant.seriesSlug, episodeSlug: episode?.slug ?? null });

  if (episode) {
    const adjacent = grant.episodeSlug ? { previous: undefined, next: undefined } : getAdjacentEpisodes(series, episode);
    return <ReaderExperience
      series={{ slug: series.slug, title: series.title }}
      episode={protectedEpisode(episode, token)}
      previous={adjacent.previous}
      next={adjacent.next}
      preview={{ token, episodeScoped: Boolean(grant.episodeSlug) }}
    />;
  }

  const root = `/preview/${encodeURIComponent(token)}`;
  const coverImage = protectedMediaUrl(series.coverImage, token);
  const visibleEpisodes = grant.episodeSlug
    ? series.episodes.filter((item) => item.slug === grant.episodeSlug)
    : series.episodes;
  return <div className="site-shell preview-shell">
    <div className="preview-ribbon" role="status">Taslak önizleme · yayınlanmadı · bağlantı 30 dakika geçerli</div>
    <main id="main-content" className="series-page">
      <section className="series-hero wrap" aria-labelledby="preview-series-title">
        <div className={`series-cover poster poster--${series.tone}${coverImage ? " poster--image" : ""}`} style={coverImage ? { backgroundImage: `url("${coverImage}")`, backgroundPosition: series.coverPosition ?? "center" } : undefined}>
          <span className="series-cover__word">{series.title}</span>
        </div>
        <div className="series-info"><p className="section-kicker">{series.eyebrow} · {series.publicationStatus === "published" ? "yayında" : "taslak"}</p><h1 id="preview-series-title">{series.title}</h1><p className="creator-line">{series.creator}</p><div className="genre-pills">{series.genres.map((genre) => <span className="pill" key={genre}>{genre}</span>)}</div><p className="series-description">{series.longDescription}</p></div>
      </section>
      <section className="episode-section wrap" aria-labelledby="preview-episodes-title"><div className="section-heading"><div><p className="section-kicker">{visibleEpisodes.length} bölüm</p><h2 id="preview-episodes-title">Taslak bölüm listesi</h2></div></div><ol className="episode-list">{visibleEpisodes.map((item) => <li key={item.slug}><Link href={`${root}?episode=${encodeURIComponent(item.slug)}`}><span className="episode-number">{String(item.number).padStart(2, "0")}</span><span className="episode-title"><strong>{item.title}</strong><small>{item.publicationStatus === "published" ? "Yayında" : "Taslak"}</small></span><span className="episode-time">{item.readTime}</span><span className="episode-arrow" aria-hidden="true">→</span></Link></li>)}</ol></section>
    </main>
  </div>;
}
