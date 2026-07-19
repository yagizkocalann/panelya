import { seriesCatalog, type Episode, type PanelTone, type Series, type StoryPanel } from "../data/catalog";
import { getDatabase } from "./database";

export type PublicationStatus = "draft" | "published" | "archived";

export type StudioEpisode = Episode & {
  id: string;
  publicationStatus: PublicationStatus;
  createdAt: number;
  updatedAt: number;
  publishedAtTimestamp: number | null;
};

export type StudioSeries = Omit<Series, "episodes"> & {
  publicationStatus: PublicationStatus;
  isFeatured: boolean;
  createdAt: number;
  updatedAtTimestamp: number;
  publishedAt: number | null;
  episodes: StudioEpisode[];
};

type SeriesRow = {
  slug: string;
  title: string;
  eyebrow: string;
  creator: string;
  description: string;
  long_description: string;
  story_status: "ongoing" | "completed";
  genres_json: string;
  tone: PanelTone;
  updated_label: string;
  rating: number;
  followers: string;
  is_new: number;
  cover_image: string | null;
  cover_position: string | null;
  publication_status: PublicationStatus;
  is_featured: number;
  created_at: number;
  updated_at: number;
  published_at: number | null;
};

type EpisodeRow = {
  id: string;
  series_slug: string;
  slug: string;
  number: number;
  title: string;
  published_label: string;
  read_time: string;
  panels_json: string;
  publication_status: PublicationStatus;
  created_at: number;
  updated_at: number;
  published_at: number | null;
};

export type SeriesInput = {
  slug: string;
  title: string;
  eyebrow: string;
  creator: string;
  description: string;
  longDescription: string;
  status: Series["status"];
  genres: string[];
  tone: PanelTone;
  updatedAt: string;
  followers: string;
  isNew: boolean;
  coverImage?: string;
  coverPosition?: string;
  publicationStatus: PublicationStatus;
  isFeatured: boolean;
};

export type EpisodeInput = {
  seriesSlug: string;
  slug: string;
  number: number;
  title: string;
  publishedAt: string;
  readTime: string;
  publicationStatus: PublicationStatus;
  panels?: StoryPanel[];
};

let seedReady: Promise<void> | null = null;

function safeArray<T>(value: string, fallback: T[] = []) {
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed as T[] : fallback;
  } catch {
    return fallback;
  }
}

async function ensureContentSeed() {
  const db = await getDatabase();
  const now = Date.now();
  const statements: D1PreparedStatement[] = [];
  // Bundled demo rasters moved from large PNG sources to Git-friendly WebP.
  // Migrate only the two known original series and keep all Studio-managed media untouched.
  statements.push(db.prepare(`UPDATE content_series
    SET cover_image = REPLACE(cover_image, '.png', '.webp'), updated_at = ?
    WHERE slug IN ('yarinki-ses', 'bir-bilet-uzaginda')
      AND cover_image LIKE '/images/%'
      AND cover_image LIKE '%.png'`).bind(now));
  statements.push(db.prepare(`UPDATE content_episodes
    SET panels_json = REPLACE(panels_json, '.png', '.webp'), updated_at = ?
    WHERE series_slug IN ('yarinki-ses', 'bir-bilet-uzaginda')
      AND panels_json LIKE '%/images/%'
      AND panels_json LIKE '%.png%'`).bind(now));
  // The bundled catalog is an idempotent baseline, not an all-or-nothing first-run
  // fixture. INSERT OR IGNORE adds newly shipped originals without overwriting
  // anything an editor has already changed in Studio.
  for (const [seriesIndex, series] of seriesCatalog.entries()) {
    statements.push(db.prepare(`INSERT OR IGNORE INTO content_series (
      slug, title, eyebrow, creator, description, long_description, story_status, genres_json, tone,
      updated_label, rating, followers, is_new, cover_image, cover_position, publication_status,
      is_featured, created_at, updated_at, published_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'published', ?, ?, ?, ?)`)
      .bind(series.slug, series.title, series.eyebrow, series.creator, series.description, series.longDescription,
        series.status === "Tamamlandı" ? "completed" : "ongoing", JSON.stringify(series.genres), series.tone,
        series.updatedAt, series.rating, series.followers, series.isNew ? 1 : 0, series.coverImage ?? null,
        series.coverPosition ?? null, seriesIndex === 0 ? 1 : 0, now, now, now));
    for (const episode of series.episodes) {
      statements.push(db.prepare(`INSERT OR IGNORE INTO content_episodes (
        id, series_slug, slug, number, title, published_label, read_time, panels_json, publication_status,
        created_at, updated_at, published_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'published', ?, ?, ?)`)
        .bind(crypto.randomUUID(), series.slug, episode.slug, episode.number, episode.title, episode.publishedAt,
          episode.readTime, JSON.stringify(episode.panels), now, now, now));
    }
  }
  if (statements.length) await db.batch(statements);
}

async function ensureReady() {
  seedReady ??= ensureContentSeed();
  await seedReady;
}

function episodeFromRow(row: EpisodeRow): StudioEpisode {
  return {
    id: row.id,
    slug: row.slug,
    number: Number(row.number),
    title: row.title,
    publishedAt: row.published_label,
    readTime: row.read_time,
    panels: safeArray<StoryPanel>(row.panels_json),
    publicationStatus: row.publication_status,
    createdAt: Number(row.created_at),
    updatedAt: Number(row.updated_at),
    publishedAtTimestamp: row.published_at == null ? null : Number(row.published_at),
  };
}

function seriesFromRow(row: SeriesRow, episodes: StudioEpisode[]): StudioSeries {
  return {
    slug: row.slug,
    title: row.title,
    eyebrow: row.eyebrow,
    creator: row.creator,
    description: row.description,
    longDescription: row.long_description,
    status: row.story_status === "completed" ? "Tamamlandı" : "Devam Ediyor",
    genres: safeArray<string>(row.genres_json),
    tone: row.tone,
    updatedAt: row.updated_label,
    rating: Number(row.rating),
    followers: row.followers,
    isNew: Boolean(row.is_new),
    coverImage: row.cover_image ?? undefined,
    coverPosition: row.cover_position ?? undefined,
    publicationStatus: row.publication_status,
    isFeatured: Boolean(row.is_featured),
    createdAt: Number(row.created_at),
    updatedAtTimestamp: Number(row.updated_at),
    publishedAt: row.published_at == null ? null : Number(row.published_at),
    episodes,
  };
}

async function listSeriesRows() {
  await ensureReady();
  const db = await getDatabase();
  const [series, episodes] = await Promise.all([
    db.prepare("SELECT * FROM content_series ORDER BY is_featured DESC, updated_at DESC, title COLLATE NOCASE").all<SeriesRow>(),
    db.prepare("SELECT * FROM content_episodes ORDER BY series_slug, number DESC").all<EpisodeRow>(),
  ]);
  const bySeries = new Map<string, StudioEpisode[]>();
  for (const row of episodes.results) {
    const list = bySeries.get(row.series_slug) ?? [];
    list.push(episodeFromRow(row));
    bySeries.set(row.series_slug, list);
  }
  return series.results.map((row) => seriesFromRow(row, bySeries.get(row.slug) ?? []));
}

export async function listStudioSeries() {
  return listSeriesRows();
}

function toPublicSeries(series: StudioSeries): Series {
  return {
    slug: series.slug,
    title: series.title,
    eyebrow: series.eyebrow,
    creator: series.creator,
    description: series.description,
    longDescription: series.longDescription,
    status: series.status,
    genres: series.genres,
    tone: series.tone,
    updatedAt: series.updatedAt,
    rating: series.rating,
    followers: series.followers,
    isNew: series.isNew,
    coverImage: series.coverImage,
    coverPosition: series.coverPosition,
    episodes: series.episodes
      .filter((episode) => episode.publicationStatus === "published")
      .map((episode): Episode => ({
        slug: episode.slug,
        number: episode.number,
        title: episode.title,
        publishedAt: episode.publishedAt,
        readTime: episode.readTime,
        panels: episode.panels,
      })),
  };
}

export async function listPublishedSeries(): Promise<Series[]> {
  try {
    const rows = await listSeriesRows();
    return rows
      .filter((series) => series.publicationStatus === "published")
      .map(toPublicSeries)
      .filter((series) => series.episodes.length > 0);
  } catch {
    // Public reads remain available during build probes or a transient D1 outage.
    return seriesCatalog;
  }
}

export async function listPublishedSeriesForSitemap() {
  try {
    const rows = await listSeriesRows();
    return rows
      .filter((series) => series.publicationStatus === "published")
      .map((series) => {
        const publishedEpisodes = series.episodes.filter((episode) => episode.publicationStatus === "published");
        const lastModified = Math.max(series.updatedAtTimestamp, ...publishedEpisodes.map((episode) => episode.updatedAt));
        return { slug: series.slug, lastModified, publishedEpisodeCount: publishedEpisodes.length };
      })
      .filter((series) => series.publishedEpisodeCount > 0);
  } catch {
    return seriesCatalog.map((series) => ({ slug: series.slug, lastModified: undefined, publishedEpisodeCount: series.episodes.length }));
  }
}

export async function getStudioSeries(slug: string) {
  return (await listSeriesRows()).find((series) => series.slug === slug);
}

export async function getPublishedSeries(slug: string) {
  return (await listPublishedSeries()).find((series) => series.slug === slug);
}

export async function getFeaturedPublishedSeries() {
  return (await listPublishedSeries())[0];
}

export async function createContentSeries(input: SeriesInput) {
  await ensureReady();
  const db = await getDatabase();
  const now = Date.now();
  const statements: D1PreparedStatement[] = [];
  if (input.isFeatured) statements.push(db.prepare("UPDATE content_series SET is_featured = 0"));
  statements.push(db.prepare(`INSERT INTO content_series (
    slug, title, eyebrow, creator, description, long_description, story_status, genres_json, tone,
    updated_label, rating, followers, is_new, cover_image, cover_position, publication_status,
    is_featured, created_at, updated_at, published_at
  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
    .bind(input.slug, input.title, input.eyebrow, input.creator, input.description, input.longDescription,
      input.status === "Tamamlandı" ? "completed" : "ongoing", JSON.stringify(input.genres), input.tone,
      input.updatedAt, input.followers, input.isNew ? 1 : 0, input.coverImage ?? null, input.coverPosition ?? null,
      input.publicationStatus, input.isFeatured ? 1 : 0, now, now, input.publicationStatus === "published" ? now : null));
  await db.batch(statements);
}

export async function updateContentSeries(slug: string, input: SeriesInput) {
  await ensureReady();
  const db = await getDatabase();
  const now = Date.now();
  const statements: D1PreparedStatement[] = [];
  if (input.isFeatured) statements.push(db.prepare("UPDATE content_series SET is_featured = 0"));
  statements.push(db.prepare(`UPDATE content_series SET
    title = ?, eyebrow = ?, creator = ?, description = ?, long_description = ?, story_status = ?, genres_json = ?,
    tone = ?, updated_label = ?, followers = ?, is_new = ?, cover_image = ?, cover_position = ?, publication_status = ?,
    is_featured = ?, updated_at = ?, published_at = CASE WHEN ? = 'published' THEN COALESCE(published_at, ?) ELSE published_at END
    WHERE slug = ?`)
    .bind(input.title, input.eyebrow, input.creator, input.description, input.longDescription,
      input.status === "Tamamlandı" ? "completed" : "ongoing", JSON.stringify(input.genres), input.tone,
      input.updatedAt, input.followers, input.isNew ? 1 : 0, input.coverImage ?? null, input.coverPosition ?? null,
      input.publicationStatus, input.isFeatured ? 1 : 0, now, input.publicationStatus, now, slug));
  await db.batch(statements);
}

export async function createContentEpisode(input: EpisodeInput) {
  await ensureReady();
  const db = await getDatabase();
  const now = Date.now();
  await db.prepare(`INSERT INTO content_episodes (
    id, series_slug, slug, number, title, published_label, read_time, panels_json, publication_status,
    created_at, updated_at, published_at
  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
    .bind(crypto.randomUUID(), input.seriesSlug, input.slug, input.number, input.title, input.publishedAt, input.readTime,
      JSON.stringify(input.panels ?? []), input.publicationStatus, now, now, input.publicationStatus === "published" ? now : null)
    .run();
}

export async function updateContentEpisode(seriesSlug: string, originalSlug: string, input: EpisodeInput) {
  await ensureReady();
  const db = await getDatabase();
  const current = await db.prepare("SELECT panels_json FROM content_episodes WHERE series_slug = ? AND slug = ?")
    .bind(seriesSlug, originalSlug).first<{ panels_json: string }>();
  if (!current) throw new Error("episode_not_found");
  const now = Date.now();
  await db.prepare(`UPDATE content_episodes SET slug = ?, number = ?, title = ?, published_label = ?, read_time = ?,
    panels_json = ?, publication_status = ?, updated_at = ?,
    published_at = CASE WHEN ? = 'published' THEN COALESCE(published_at, ?) ELSE published_at END
    WHERE series_slug = ? AND slug = ?`)
    .bind(input.slug, input.number, input.title, input.publishedAt, input.readTime,
      input.panels ? JSON.stringify(input.panels) : current.panels_json, input.publicationStatus, now,
      input.publicationStatus, now, seriesSlug, originalSlug).run();
}

export async function getContentCounts() {
  await ensureReady();
  const db = await getDatabase();
  const [series, episodes] = await Promise.all([
    db.prepare("SELECT COUNT(*) AS count FROM content_series").first<{ count: number }>(),
    db.prepare("SELECT COUNT(*) AS count FROM content_episodes").first<{ count: number }>(),
  ]);
  return { series: Number(series?.count ?? 0), episodes: Number(episodes?.count ?? 0) };
}

export function genresFromSeries(series: Series[]) {
  return Array.from(new Set(series.flatMap((item) => item.genres))).sort((a, b) => a.localeCompare(b, "tr"));
}
