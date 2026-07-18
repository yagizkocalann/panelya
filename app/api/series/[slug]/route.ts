import { getPublishedSeries } from "../../../lib/content-repository";

type RouteContext = { params: Promise<{ slug: string }> };

export async function GET(_request: Request, { params }: RouteContext) {
  const { slug } = await params;
  const series = await getPublishedSeries(slug);
  if (!series) return Response.json({ error: "series_not_found" }, { status: 404 });
  const { episodes, ...metadata } = series;
  return Response.json({
    schemaVersion: "1.0",
    series: metadata,
    episodes: episodes.map(({ panels, ...episode }) => ({ ...episode, panelCount: panels.length })),
  }, { headers: { "Cache-Control": "public, max-age=60, stale-while-revalidate=300" } });
}
