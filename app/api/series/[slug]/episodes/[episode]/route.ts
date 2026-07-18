import { getAdjacentEpisodes, getEpisode } from "../../../../../data/catalog";
import { getPublishedSeries } from "../../../../../lib/content-repository";

type RouteContext = { params: Promise<{ slug: string; episode: string }> };

export async function GET(_request: Request, { params }: RouteContext) {
  const { slug, episode: episodeSlug } = await params;
  const series = await getPublishedSeries(slug);
  const episode = series ? getEpisode(series, episodeSlug) : undefined;
  if (!series || !episode) return Response.json({ error: "episode_not_found" }, { status: 404 });
  const adjacent = getAdjacentEpisodes(series, episode);
  return Response.json({
    schemaVersion: "1.0",
    series: { slug: series.slug, title: series.title },
    episode,
    navigation: {
      previous: adjacent.previous ? { slug: adjacent.previous.slug, number: adjacent.previous.number } : null,
      next: adjacent.next ? { slug: adjacent.next.slug, number: adjacent.next.number } : null,
    },
  }, { headers: { "Cache-Control": "public, max-age=60, stale-while-revalidate=300" } });
}
