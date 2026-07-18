import { listPublishedSeries } from "../../lib/content-repository";

export async function GET() {
  const seriesCatalog = await listPublishedSeries();
  const featuredSeries = seriesCatalog[0];
  return Response.json({
    schemaVersion: "1.0",
    featuredSlug: featuredSeries?.slug ?? null,
    series: seriesCatalog.map(({ episodes, ...series }) => ({ ...series, episodeCount: episodes.length, latestEpisode: episodes[0] })),
  }, { headers: { "Cache-Control": "public, max-age=60, stale-while-revalidate=300" } });
}
