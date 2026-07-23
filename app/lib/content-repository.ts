import { seriesCatalog, type Episode, type PanelTone, type PublicMediaVariant, type Series, type StoryPanel } from "../data/catalog";
import { localDummySeriesCatalog } from "../data/local-dummy-catalog";
import { getDatabase } from "./database";
import { isRecentlyPublished } from "./series-recency";

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
  search_text: string;
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

type CatalogQueryRow = SeriesRow & { discovery_updated_at: number };

export type CatalogSort = "updated" | "rating" | "title";
export type CatalogStatus = "ongoing" | "completed";
export type CatalogSearchInput = {
  query?: string;
  genre?: string;
  status?: string;
  sort?: string;
  cursor?: string;
  limit?: number;
};

export type CatalogSearchResult = {
  items: Series[];
  nextCursor: string | null;
  cursorWasInvalid: boolean;
  filters: { query: string; genre: string; status: CatalogStatus | ""; sort: CatalogSort };
};

export type CatalogPageInput = Omit<CatalogSearchInput, "cursor" | "limit"> & {
  page?: number;
  pageSize?: number;
};

export type CatalogPageResult = {
  items: Series[];
  page: number;
  pageSize: 8 | 16 | 32;
  totalItems: number;
  totalPages: number;
  filters: CatalogSearchResult["filters"];
};

type CatalogCursor = { version: 1; sort: CatalogSort; scope: string; value: string | number; slug: string };

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

type PublicMediaVariantRow = {
  asset_id: string;
  mime_type: "image/webp";
  width: number;
  height: number;
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

function localDummyCatalogEnabled() {
  const configured = process.env.LOCAL_DUMMY_CATALOG?.trim().toLowerCase();
  if (configured === "true" || configured === "1") return true;
  if (configured === "false" || configured === "0") return false;
  return process.env.NODE_ENV !== "production";
}

function bundledCatalog() {
  return localDummyCatalogEnabled() ? [...seriesCatalog, ...localDummySeriesCatalog] : seriesCatalog;
}

function safeArray<T>(value: string, fallback: T[] = []) {
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed as T[] : fallback;
  } catch {
    return fallback;
  }
}

export function normalizeCatalogSearch(value: string) {
  return value
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase("tr")
    .replaceAll("\u0131", "i")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function catalogSearchText(input: Pick<Series, "title" | "creator" | "eyebrow" | "description" | "genres">) {
  return normalizeCatalogSearch([input.title, input.creator, input.eyebrow, input.description, ...input.genres].join(" "));
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
  for (const [seriesIndex, series] of bundledCatalog().entries()) {
    statements.push(db.prepare(`INSERT OR IGNORE INTO content_series (
      slug, title, eyebrow, creator, search_text, description, long_description, story_status, genres_json, tone,
      updated_label, rating, followers, is_new, cover_image, cover_position, publication_status,
      is_featured, created_at, updated_at, published_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'published', ?, ?, ?, ?)`)
      .bind(series.slug, series.title, series.eyebrow, series.creator, catalogSearchText(series), series.description, series.longDescription,
        series.status === "Tamamlandı" ? "completed" : "ongoing", JSON.stringify(series.genres), series.tone,
        series.updatedAt, series.rating, series.followers, 0, series.coverImage ?? null,
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
  for (let offset = 0; offset < statements.length; offset += 75) {
    await db.batch(statements.slice(offset, offset + 75));
  }
  const missingSearchText = await db.prepare(`SELECT slug, title, eyebrow, creator, description, genres_json
    FROM content_series WHERE search_text = ''`).all<Pick<SeriesRow, "slug" | "title" | "eyebrow" | "creator" | "description" | "genres_json">>();
  if (missingSearchText.results.length) {
    await db.batch(missingSearchText.results.map((row) => db.prepare("UPDATE content_series SET search_text = ? WHERE slug = ?")
      .bind(catalogSearchText({
        title: row.title,
        creator: row.creator,
        eyebrow: row.eyebrow,
        description: row.description,
        genres: safeArray<string>(row.genres_json),
      }), row.slug)));
  }
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
    isNew: isRecentlyPublished(row.published_at == null ? null : Number(row.published_at)),
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

function bundledPublicFallback(): Series[] {
  // Bundled originals do not carry a trustworthy first-publication timestamp.
  // During a D1 outage, keep them readable without guessing that they are new.
  return bundledCatalog().map((series) => ({ ...series, isNew: localDummyCatalogEnabled() && series.slug.startsWith("yerel-demo-") }));
}

function publicMediaAssetId(src: string | undefined) {
  const match = src?.match(/^\/api\/media\/([A-Za-z0-9_-]{1,80})$/);
  return match?.[1] ?? null;
}

function mediaSources(series: Series[]) {
  const sources = new Map<string, string>();
  for (const item of series) {
    const coverId = publicMediaAssetId(item.coverImage);
    if (coverId && item.coverImage) sources.set(coverId, item.coverImage);
    for (const episode of item.episodes) {
      for (const panel of episode.panels) {
        const assetId = publicMediaAssetId(panel.image?.src);
        if (assetId && panel.image) sources.set(assetId, panel.image.src);
      }
    }
  }
  return sources;
}

async function attachPublicMediaVariants(series: Series[]) {
  const sources = mediaSources(series);
  if (!sources.size) return series;
  try {
    const db = await getDatabase();
    const rows: PublicMediaVariantRow[] = [];
    const assetIds = Array.from(sources.keys());
    for (let offset = 0; offset < assetIds.length; offset += 100) {
      const chunk = assetIds.slice(offset, offset + 100);
      const placeholders = chunk.map(() => "?").join(", ");
      const result = await db.prepare(`SELECT asset_id, mime_type, width, height FROM media_variants
        WHERE asset_id IN (${placeholders}) AND mime_type = 'image/webp' ORDER BY asset_id, width`).bind(...chunk).all<PublicMediaVariantRow>();
      rows.push(...result.results);
    }
    const variantsBySource = new Map<string, PublicMediaVariant[]>();
    for (const row of rows) {
      const source = sources.get(row.asset_id);
      if (!source) continue;
      const variants = variantsBySource.get(source) ?? [];
      variants.push({ src: `${source}?width=${Number(row.width)}`, width: Number(row.width), height: Number(row.height), mimeType: row.mime_type });
      variantsBySource.set(source, variants);
    }
    return series.map((item): Series => ({
      ...item,
      ...(item.coverImage && variantsBySource.has(item.coverImage) ? { coverImageVariants: variantsBySource.get(item.coverImage) } : {}),
      episodes: item.episodes.map((episode) => ({
        ...episode,
        panels: episode.panels.map((panel) => panel.image && variantsBySource.has(panel.image.src)
          ? { ...panel, image: { ...panel.image, variants: variantsBySource.get(panel.image.src) } }
          : panel),
      })),
    }));
  } catch {
    // Responsive metadata is an optimization. Published originals remain readable
    // through their source URL if the variant lookup is temporarily unavailable.
    return series;
  }
}

export async function listPublishedSeries(): Promise<Series[]> {
  try {
    const rows = await listSeriesRows();
    const published = rows
      .filter((series) => series.publicationStatus === "published")
      .map(toPublicSeries)
      .filter((series) => series.episodes.length > 0);
    return attachPublicMediaVariants(published);
  } catch {
    // Public reads remain available during build probes or a transient D1 outage.
    return bundledPublicFallback();
  }
}

export type PublishedEpisodeUpdate = {
  series: Series;
  episode: Episode;
  publishedAtTimestamp: number;
};

export async function listPublishedEpisodeUpdates(limit = 24): Promise<PublishedEpisodeUpdate[]> {
  const safeLimit = Math.max(1, Math.min(100, Math.trunc(limit)));
  try {
    const rows = await listSeriesRows();
    const publishedRows = rows.filter((series) => series.publicationStatus === "published");
    const publicSeries = await attachPublicMediaVariants(publishedRows.map(toPublicSeries));
    const seriesBySlug = new Map(publicSeries.map((series) => [series.slug, series]));

    return publishedRows
      .flatMap((series) => series.episodes
        .filter((episode) => episode.publicationStatus === "published")
        .map((episode) => ({
          seriesSlug: series.slug,
          episodeSlug: episode.slug,
          publishedAtTimestamp: episode.publishedAtTimestamp ?? episode.updatedAt,
        })))
      .sort((a, b) => b.publishedAtTimestamp - a.publishedAtTimestamp
        || a.seriesSlug.localeCompare(b.seriesSlug)
        || a.episodeSlug.localeCompare(b.episodeSlug))
      .slice(0, safeLimit)
      .flatMap((item) => {
        const series = seriesBySlug.get(item.seriesSlug);
        const episode = series?.episodes.find((candidate) => candidate.slug === item.episodeSlug);
        return series && episode ? [{ series, episode, publishedAtTimestamp: item.publishedAtTimestamp }] : [];
      });
  } catch {
    const fallback = bundledPublicFallback();
    return fallback
      .flatMap((series, seriesIndex) => series.episodes.map((episode) => ({
        series,
        episode,
        publishedAtTimestamp: (fallback.length - seriesIndex) * 1_000_000 + episode.number,
      })))
      .sort((a, b) => b.publishedAtTimestamp - a.publishedAtTimestamp)
      .slice(0, safeLimit);
  }
}

function encodeCatalogCursor(cursor: CatalogCursor) {
  const bytes = new TextEncoder().encode(JSON.stringify(cursor));
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/g, "");
}

function decodeCatalogCursor(value: string | undefined, sort: CatalogSort, scope: string): CatalogCursor | null {
  if (!value || value.length > 512) return null;
  try {
    const base64 = value.replaceAll("-", "+").replaceAll("_", "/").padEnd(Math.ceil(value.length / 4) * 4, "=");
    const binary = atob(base64);
    const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
    const parsed = JSON.parse(new TextDecoder().decode(bytes)) as Partial<CatalogCursor>;
    const valueIsValid = sort === "title"
      ? typeof parsed.value === "string" && parsed.value.length <= 200
      : typeof parsed.value === "number" && Number.isFinite(parsed.value);
    if (parsed.version !== 1 || parsed.sort !== sort || parsed.scope !== scope || !valueIsValid || typeof parsed.slug !== "string" || !/^[a-z0-9-]{1,80}$/.test(parsed.slug)) return null;
    return parsed as CatalogCursor;
  } catch {
    return null;
  }
}

function normalizedCatalogFilters(input: CatalogSearchInput) {
  const query = (input.query ?? "").trim().slice(0, 80);
  const genre = (input.genre ?? "").trim().slice(0, 50);
  const status: CatalogStatus | "" = input.status === "ongoing" || input.status === "completed" ? input.status : "";
  const sort: CatalogSort = input.sort === "rating" || input.sort === "title" ? input.sort : "updated";
  const requestedLimit = typeof input.limit === "number" && Number.isFinite(input.limit) ? Math.trunc(input.limit) : 4;
  const limit = Math.max(1, Math.min(12, requestedLimit));
  return { query, normalizedQuery: normalizeCatalogSearch(query), genre, status, sort, limit };
}

function catalogCursorScope(filters: ReturnType<typeof normalizedCatalogFilters>) {
  return [filters.normalizedQuery, normalizeCatalogSearch(filters.genre), filters.status].join("|");
}

function fallbackCatalogSearch(filters: ReturnType<typeof normalizedCatalogFilters>): Series[] {
  const items = bundledPublicFallback().filter((series) => {
    const matchesSearch = !filters.normalizedQuery || catalogSearchText(series).includes(filters.normalizedQuery);
    const matchesGenre = !filters.genre || series.genres.some((genre) => genre.localeCompare(filters.genre, "tr", { sensitivity: "base" }) === 0);
    const storyStatus = series.status === "Tamamland\u0131" ? "completed" : "ongoing";
    return matchesSearch && matchesGenre && (!filters.status || storyStatus === filters.status);
  });
  if (filters.sort === "rating") return items.sort((a, b) => b.rating - a.rating || a.slug.localeCompare(b.slug));
  if (filters.sort === "title") return items.sort((a, b) => a.title.localeCompare(b.title, "tr") || a.slug.localeCompare(b.slug));
  return items;
}

export async function searchPublishedSeries(input: CatalogSearchInput = {}): Promise<CatalogSearchResult> {
  const filters = normalizedCatalogFilters(input);
  const cursorScope = catalogCursorScope(filters);
  const decodedCursor = decodeCatalogCursor(input.cursor, filters.sort, cursorScope);
  const cursorWasInvalid = Boolean(input.cursor && !decodedCursor);
  try {
    await ensureReady();
    const db = await getDatabase();
    const where = [
      "publication_status = 'published'",
      "EXISTS (SELECT 1 FROM content_episodes ce WHERE ce.series_slug = catalog.slug AND ce.publication_status = 'published')",
    ];
    const bindings: Array<string | number> = [];
    if (filters.normalizedQuery) {
      where.push("search_text LIKE ?");
      bindings.push(`%${filters.normalizedQuery}%`);
    }
    if (filters.genre) {
      where.push("EXISTS (SELECT 1 FROM json_each(catalog.genres_json) genre WHERE genre.value = ? COLLATE NOCASE)");
      bindings.push(filters.genre);
    }
    if (filters.status) {
      where.push("story_status = ?");
      bindings.push(filters.status);
    }

    let orderBy = "discovery_updated_at DESC, slug ASC";
    if (filters.sort === "rating") orderBy = "rating DESC, slug ASC";
    if (filters.sort === "title") orderBy = "title COLLATE NOCASE ASC, slug ASC";
    if (decodedCursor) {
      if (filters.sort === "updated" && typeof decodedCursor.value === "number") {
        where.push("(discovery_updated_at < ? OR (discovery_updated_at = ? AND slug > ?))");
        bindings.push(decodedCursor.value, decodedCursor.value, decodedCursor.slug);
      } else if (filters.sort === "rating" && typeof decodedCursor.value === "number") {
        where.push("(rating < ? OR (rating = ? AND slug > ?))");
        bindings.push(decodedCursor.value, decodedCursor.value, decodedCursor.slug);
      } else if (filters.sort === "title" && typeof decodedCursor.value === "string") {
        where.push("(title > ? COLLATE NOCASE OR (title = ? COLLATE NOCASE AND slug > ?))");
        bindings.push(decodedCursor.value, decodedCursor.value, decodedCursor.slug);
      }
    }

    const result = await db.prepare(`WITH catalog AS (
      SELECT cs.*, COALESCE(
        (SELECT MAX(COALESCE(ce.published_at, ce.updated_at)) FROM content_episodes ce
          WHERE ce.series_slug = cs.slug AND ce.publication_status = 'published'),
        cs.published_at, cs.updated_at
      ) AS discovery_updated_at
      FROM content_series cs
    )
    SELECT * FROM catalog WHERE ${where.join(" AND ")}
    ORDER BY ${orderBy} LIMIT ?`).bind(...bindings, filters.limit + 1).all<CatalogQueryRow>();

    const pageRows = result.results.slice(0, filters.limit);
    const bySeries = new Map<string, StudioEpisode[]>();
    if (pageRows.length) {
      const placeholders = pageRows.map(() => "?").join(", ");
      const episodes = await db.prepare(`SELECT * FROM content_episodes
        WHERE publication_status = 'published' AND series_slug IN (${placeholders})
        ORDER BY series_slug, number DESC`).bind(...pageRows.map((row) => row.slug)).all<EpisodeRow>();
      for (const row of episodes.results) {
        const list = bySeries.get(row.series_slug) ?? [];
        list.push(episodeFromRow(row));
        bySeries.set(row.series_slug, list);
      }
    }
    const items = await attachPublicMediaVariants(pageRows.map((row) => toPublicSeries(seriesFromRow(row, bySeries.get(row.slug) ?? []))));
    const lastRow = pageRows.at(-1);
    let nextCursor: string | null = null;
    if (result.results.length > filters.limit && lastRow) {
      const value = filters.sort === "updated" ? Number(lastRow.discovery_updated_at) : filters.sort === "rating" ? Number(lastRow.rating) : lastRow.title;
      nextCursor = encodeCatalogCursor({ version: 1, sort: filters.sort, scope: cursorScope, value, slug: lastRow.slug });
    }
    return { items, nextCursor, cursorWasInvalid, filters: { query: filters.query, genre: filters.genre, status: filters.status, sort: filters.sort } };
  } catch {
    return {
      items: fallbackCatalogSearch(filters),
      nextCursor: null,
      cursorWasInvalid,
      filters: { query: filters.query, genre: filters.genre, status: filters.status, sort: filters.sort },
    };
  }
}

export async function searchPublishedSeriesPage(input: CatalogPageInput = {}): Promise<CatalogPageResult> {
  const filters = normalizedCatalogFilters(input);
  const requestedPage = typeof input.page === "number" && Number.isFinite(input.page)
    ? Math.max(1, Math.min(10_000, Math.trunc(input.page)))
    : 1;
  const pageSize: 8 | 16 | 32 = input.pageSize === 16 || input.pageSize === 32 ? input.pageSize : 8;
  try {
    await ensureReady();
    const db = await getDatabase();
    const where = [
      "publication_status = 'published'",
      "EXISTS (SELECT 1 FROM content_episodes ce WHERE ce.series_slug = catalog.slug AND ce.publication_status = 'published')",
    ];
    const bindings: Array<string | number> = [];
    if (filters.normalizedQuery) {
      where.push("search_text LIKE ?");
      bindings.push(`%${filters.normalizedQuery}%`);
    }
    if (filters.genre) {
      where.push("EXISTS (SELECT 1 FROM json_each(catalog.genres_json) genre WHERE genre.value = ? COLLATE NOCASE)");
      bindings.push(filters.genre);
    }
    if (filters.status) {
      where.push("story_status = ?");
      bindings.push(filters.status);
    }
    const catalogCte = `WITH catalog AS (
      SELECT cs.*, COALESCE(
        (SELECT MAX(COALESCE(ce.published_at, ce.updated_at)) FROM content_episodes ce
          WHERE ce.series_slug = cs.slug AND ce.publication_status = 'published'),
        cs.published_at, cs.updated_at
      ) AS discovery_updated_at
      FROM content_series cs
    )`;
    const countRow = await db.prepare(`${catalogCte} SELECT COUNT(*) AS count FROM catalog WHERE ${where.join(" AND ")}`)
      .bind(...bindings).first<{ count: number }>();
    const totalItems = Number(countRow?.count ?? 0);
    const totalPages = Math.ceil(totalItems / pageSize);
    const page = totalPages ? Math.min(requestedPage, totalPages) : 1;
    const orderBy = filters.sort === "rating"
      ? "rating DESC, slug ASC"
      : filters.sort === "title"
        ? "title COLLATE NOCASE ASC, slug ASC"
        : "discovery_updated_at DESC, slug ASC";
    const result = await db.prepare(`${catalogCte} SELECT * FROM catalog WHERE ${where.join(" AND ")}
      ORDER BY ${orderBy} LIMIT ? OFFSET ?`).bind(...bindings, pageSize, (page - 1) * pageSize).all<CatalogQueryRow>();
    const bySeries = new Map<string, StudioEpisode[]>();
    if (result.results.length) {
      const placeholders = result.results.map(() => "?").join(", ");
      const episodes = await db.prepare(`SELECT * FROM content_episodes
        WHERE publication_status = 'published' AND series_slug IN (${placeholders})
        ORDER BY series_slug, number DESC`).bind(...result.results.map((row) => row.slug)).all<EpisodeRow>();
      for (const row of episodes.results) {
        const list = bySeries.get(row.series_slug) ?? [];
        list.push(episodeFromRow(row));
        bySeries.set(row.series_slug, list);
      }
    }
    const items = await attachPublicMediaVariants(result.results.map((row) => toPublicSeries(seriesFromRow(row, bySeries.get(row.slug) ?? []))));
    return {
      items,
      page,
      pageSize,
      totalItems,
      totalPages,
      filters: { query: filters.query, genre: filters.genre, status: filters.status, sort: filters.sort },
    };
  } catch {
    const allItems = fallbackCatalogSearch(filters);
    const totalItems = allItems.length;
    const totalPages = Math.ceil(totalItems / pageSize);
    const page = totalPages ? Math.min(requestedPage, totalPages) : 1;
    return {
      items: allItems.slice((page - 1) * pageSize, page * pageSize),
      page,
      pageSize,
      totalItems,
      totalPages,
      filters: { query: filters.query, genre: filters.genre, status: filters.status, sort: filters.sort },
    };
  }
}

export async function listPublishedGenres() {
  try {
    await ensureReady();
    const db = await getDatabase();
    const result = await db.prepare(`SELECT genres_json FROM content_series cs
      WHERE publication_status = 'published'
        AND EXISTS (SELECT 1 FROM content_episodes ce WHERE ce.series_slug = cs.slug AND ce.publication_status = 'published')`).all<Pick<SeriesRow, "genres_json">>();
    return Array.from(new Set(result.results.flatMap((row) => safeArray<string>(row.genres_json))))
      .sort((a, b) => a.localeCompare(b, "tr"));
  } catch {
    return genresFromSeries(bundledCatalog());
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
    return bundledCatalog().map((series) => ({ slug: series.slug, lastModified: undefined, publishedEpisodeCount: series.episodes.length }));
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
    slug, title, eyebrow, creator, search_text, description, long_description, story_status, genres_json, tone,
    updated_label, rating, followers, is_new, cover_image, cover_position, publication_status,
    is_featured, created_at, updated_at, published_at
  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, 0, ?, ?, ?, ?, ?, ?, ?)`)
    .bind(input.slug, input.title, input.eyebrow, input.creator, catalogSearchText(input), input.description, input.longDescription,
      input.status === "Tamamlandı" ? "completed" : "ongoing", JSON.stringify(input.genres), input.tone,
      input.updatedAt, input.followers, input.coverImage ?? null, input.coverPosition ?? null,
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
    title = ?, eyebrow = ?, creator = ?, search_text = ?, description = ?, long_description = ?, story_status = ?, genres_json = ?,
    tone = ?, updated_label = ?, followers = ?, cover_image = ?, cover_position = ?, publication_status = ?,
    is_featured = ?, updated_at = ?, published_at = CASE WHEN ? = 'published' THEN COALESCE(published_at, ?) ELSE published_at END
    WHERE slug = ?`)
    .bind(input.title, input.eyebrow, input.creator, catalogSearchText(input), input.description, input.longDescription,
      input.status === "Tamamlandı" ? "completed" : "ongoing", JSON.stringify(input.genres), input.tone,
      input.updatedAt, input.followers, input.coverImage ?? null, input.coverPosition ?? null,
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
