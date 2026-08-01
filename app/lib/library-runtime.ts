import type { Series } from "../data/catalog";
import { getPublishedSeries, listPublishedSeries } from "./content-repository";
import { AccountRuntimeError } from "./account-runtime";
import { Auth0RuntimeError } from "./auth0-runtime";
import { getDatabase } from "./database";

export const LIBRARY_STATUSES = ["plan", "reading", "completed", "paused", "dropped"] as const;
export type LibraryStatus = (typeof LIBRARY_STATUSES)[number];

type LibraryRow = {
  series_slug: string;
  status: string;
  is_favorite: number;
  updated_at: number;
};

function libraryHeaders(retryAfterSeconds?: number) {
  return {
    "Cache-Control": "private, no-store",
    "Referrer-Policy": "no-referrer",
    ...(retryAfterSeconds ? { "Retry-After": String(retryAfterSeconds) } : {}),
  };
}

export function libraryErrorResponse(error: unknown) {
  if (error instanceof Auth0RuntimeError) {
    const code = error.code === "insufficient_scope"
      ? "insufficient_scope"
      : error.code === "rate_limited"
        ? "rate_limited"
        : error.code === "service_unavailable"
          ? "service_unavailable"
          : "not_authenticated";
    return Response.json({
      schemaVersion: "1.0",
      error: code,
      errorDescription: error.message.slice(0, 240),
      ...(error.retryAfterSeconds ? { retryAfterSeconds: error.retryAfterSeconds } : {}),
    }, { status: error.status, headers: libraryHeaders(error.retryAfterSeconds) });
  }
  const runtimeError = error instanceof AccountRuntimeError
    ? error
    : new AccountRuntimeError("service_unavailable", "Kütüphane işlemi tamamlanamadı.", 503, false, 60);
  const supportedCode = [
    "not_authenticated",
    "invalid_request",
    "not_found",
    "rate_limited",
    "service_unavailable",
  ].includes(runtimeError.code) ? runtimeError.code : "invalid_request";
  return Response.json({
    schemaVersion: "1.0",
    error: supportedCode,
    errorDescription: runtimeError.message.slice(0, 240),
    ...(runtimeError.retryAfterSeconds ? { retryAfterSeconds: runtimeError.retryAfterSeconds } : {}),
  }, { status: runtimeError.status, headers: libraryHeaders(runtimeError.retryAfterSeconds) });
}

export function parseLibrarySlug(value: string) {
  if (!/^[a-z0-9-]{1,80}$/.test(value)) {
    throw new AccountRuntimeError("invalid_request", "Seri adresi geçersiz.", 400);
  }
  return value;
}

export function parseLibraryStatus(value: unknown): LibraryStatus {
  if (typeof value !== "string" || !(LIBRARY_STATUSES as readonly string[]).includes(value)) {
    throw new AccountRuntimeError("invalid_request", "Kütüphane durumu geçersiz.", 400);
  }
  return value as LibraryStatus;
}

export function parseLibraryFavorite(value: unknown) {
  if (typeof value !== "boolean") {
    throw new AccountRuntimeError("invalid_request", "Favori değeri doğru veya yanlış olmalı.", 400);
  }
  return value;
}

export function publicSeriesSummary(series: Series) {
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
    ...(typeof series.isNew === "boolean" ? { isNew: series.isNew } : {}),
    ...(series.coverImage ? { coverImage: series.coverImage } : {}),
    ...(series.coverImageVariants ? { coverImageVariants: series.coverImageVariants } : {}),
    ...(series.coverPosition ? { coverPosition: series.coverPosition } : {}),
    episodeCount: series.episodes.length,
  };
}

function rowToLibraryItem(row: LibraryRow, series: Series) {
  return {
    series: publicSeriesSummary(series),
    status: parseLibraryStatus(row.status),
    favorite: Boolean(row.is_favorite),
    updatedAt: new Date(Number(row.updated_at)).toISOString(),
  };
}

export async function listLibraryItems(userId: string) {
  const [db, series] = await Promise.all([getDatabase(), listPublishedSeries()]);
  const result = await db.prepare(`SELECT series_slug, status, is_favorite, updated_at
    FROM library_items WHERE user_id = ? ORDER BY updated_at DESC, series_slug ASC`)
    .bind(userId).all<LibraryRow>();
  const seriesBySlug = new Map(series.map((item) => [item.slug, item]));
  return result.results.flatMap((row) => {
    const publishedSeries = seriesBySlug.get(row.series_slug);
    return publishedSeries ? [rowToLibraryItem(row, publishedSeries)] : [];
  });
}

export async function getLibraryItem(userId: string, slug: string) {
  const [db, series] = await Promise.all([getDatabase(), getPublishedSeries(parseLibrarySlug(slug))]);
  if (!series) return null;
  const row = await db.prepare(`SELECT series_slug, status, is_favorite, updated_at
    FROM library_items WHERE user_id = ? AND series_slug = ?`)
    .bind(userId, slug).first<LibraryRow>();
  return row ? rowToLibraryItem(row, series) : null;
}

export async function upsertLibraryItem(
  userId: string,
  slug: string,
  status: LibraryStatus,
  favorite: boolean,
) {
  const validSlug = parseLibrarySlug(slug);
  if (!(await getPublishedSeries(validSlug))) {
    throw new AccountRuntimeError("not_found", "Seri bulunamadı.", 404);
  }
  const db = await getDatabase();
  const now = Date.now();
  await db.prepare(`INSERT INTO library_items
      (user_id, series_slug, status, is_favorite, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?)
    ON CONFLICT(user_id, series_slug) DO UPDATE SET
      status = excluded.status,
      is_favorite = excluded.is_favorite,
      updated_at = excluded.updated_at`)
    .bind(userId, validSlug, status, favorite ? 1 : 0, now, now).run();
  const item = await getLibraryItem(userId, validSlug);
  if (!item) throw new AccountRuntimeError("service_unavailable", "Kütüphane kaydı okunamadı.", 503, false, 60);
  return item;
}

export async function removeLibraryItem(userId: string, slug: string) {
  const validSlug = parseLibrarySlug(slug);
  const db = await getDatabase();
  const result = await db.prepare("DELETE FROM library_items WHERE user_id = ? AND series_slug = ?")
    .bind(userId, validSlug).run();
  return Number(result.meta.changes ?? 0) > 0;
}

export const LIBRARY_JSON_HEADERS = libraryHeaders();
