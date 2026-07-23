import type { Episode, Series } from "../../data/catalog";
import { listPublishedEpisodeUpdates, listPublishedGenres, listPublishedSeries } from "../../lib/content-repository";

function summarizeSeries(series: Series) {
  const { episodes, ...metadata } = series;
  return { ...metadata, episodeCount: episodes.length };
}

function summarizeEpisode(episode: Episode) {
  const { panels, ...metadata } = episode;
  return { ...metadata, panelCount: panels.length };
}

export async function GET() {
  const [seriesCatalog, genres, episodeUpdates] = await Promise.all([
    listPublishedSeries(),
    listPublishedGenres(),
    listPublishedEpisodeUpdates(100),
  ]);
  const featuredSeries = seriesCatalog[0] ?? null;
  const featuredFirstEpisode = featuredSeries
    ? [...featuredSeries.episodes].sort((a, b) => a.number - b.number)[0] ?? null
    : null;

  return Response.json({
    schemaVersion: "1.0",
    featuredSeries: featuredSeries ? summarizeSeries(featuredSeries) : null,
    featuredFirstEpisode: featuredFirstEpisode ? summarizeEpisode(featuredFirstEpisode) : null,
    genres,
    newSeries: seriesCatalog.filter((series) => series.isNew).slice(0, 100).map(summarizeSeries),
    latestEpisodes: episodeUpdates.map(({ series, episode }) => ({
      series: summarizeSeries(series),
      episode: summarizeEpisode(episode),
    })),
  }, { headers: { "Cache-Control": "public, max-age=60, stale-while-revalidate=300" } });
}
