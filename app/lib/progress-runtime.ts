import { getEpisode, type Episode, type Series } from "../data/catalog";
import { getPublishedSeries, listPublishedSeries } from "./content-repository";
import { AccountRuntimeError } from "./account-runtime";
import { Auth0RuntimeError } from "./auth0-runtime";
import { getDatabase } from "./database";
import { publicSeriesSummary } from "./library-runtime";

type ProgressRow = {
  series_slug: string;
  episode_slug: string;
  percent: number;
  updated_at: number;
};

function progressHeaders(retryAfterSeconds?: number) {
  return {
    "Cache-Control": "private, no-store",
    "Referrer-Policy": "no-referrer",
    ...(retryAfterSeconds ? { "Retry-After": String(retryAfterSeconds) } : {}),
  };
}

export function progressErrorResponse(error: unknown) {
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
    }, { status: error.status, headers: progressHeaders(error.retryAfterSeconds) });
  }
  const runtimeError = error instanceof AccountRuntimeError
    ? error
    : new AccountRuntimeError("service_unavailable", "Okuma ilerlemesi işlenemedi.", 503, false, 60);
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
  }, { status: runtimeError.status, headers: progressHeaders(runtimeError.retryAfterSeconds) });
}

export function parseProgressSlug(value: unknown, label: "seri" | "bölüm") {
  if (typeof value !== "string" || !/^[a-z0-9-]{1,80}$/.test(value)) {
    throw new AccountRuntimeError("invalid_request", `${label === "seri" ? "Seri" : "Bölüm"} adresi geçersiz.`, 400);
  }
  return value;
}

export function parseProgressPercent(value: unknown) {
  if (typeof value !== "number" || !Number.isInteger(value) || value < 0 || value > 100) {
    throw new AccountRuntimeError("invalid_request", "Okuma yüzdesi 0 ile 100 arasında tam sayı olmalı.", 400);
  }
  return value;
}

function publicEpisodeSummary(episode: Episode) {
  return {
    slug: episode.slug,
    number: episode.number,
    title: episode.title,
    publishedAt: episode.publishedAt,
    readTime: episode.readTime,
    panelCount: episode.panels.length,
  };
}

function rowToProgressItem(row: ProgressRow, series: Series, episode: Episode) {
  return {
    series: publicSeriesSummary(series),
    episode: publicEpisodeSummary(episode),
    percent: Number(row.percent),
    updatedAt: new Date(Number(row.updated_at)).toISOString(),
  };
}

export async function listProgressItems(userId: string) {
  const [db, series] = await Promise.all([getDatabase(), listPublishedSeries()]);
  const result = await db.prepare(`SELECT series_slug, episode_slug, percent, updated_at
    FROM reading_progress WHERE user_id = ? ORDER BY updated_at DESC, series_slug ASC`)
    .bind(userId).all<ProgressRow>();
  const seriesBySlug = new Map(series.map((item) => [item.slug, item]));
  return result.results.flatMap((row) => {
    const publishedSeries = seriesBySlug.get(row.series_slug);
    const episode = publishedSeries && getEpisode(publishedSeries, row.episode_slug);
    return publishedSeries && episode ? [rowToProgressItem(row, publishedSeries, episode)] : [];
  });
}

export async function upsertProgressItem(
  userId: string,
  seriesSlugValue: unknown,
  episodeSlugValue: unknown,
  percentValue: unknown,
) {
  const seriesSlug = parseProgressSlug(seriesSlugValue, "seri");
  const episodeSlug = parseProgressSlug(episodeSlugValue, "bölüm");
  const percent = parseProgressPercent(percentValue);
  const series = await getPublishedSeries(seriesSlug);
  const episode = series && getEpisode(series, episodeSlug);
  if (!series || !episode) {
    throw new AccountRuntimeError("not_found", "Yayınlanmış seri veya bölüm bulunamadı.", 404);
  }
  const db = await getDatabase();
  const updatedAt = Date.now();
  await db.prepare(`INSERT INTO reading_progress
      (user_id, series_slug, episode_slug, episode_number, episode_title, percent, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(user_id, series_slug) DO UPDATE SET
      episode_slug = excluded.episode_slug,
      episode_number = excluded.episode_number,
      episode_title = excluded.episode_title,
      percent = excluded.percent,
      updated_at = excluded.updated_at`)
    .bind(userId, series.slug, episode.slug, episode.number, episode.title, percent, updatedAt).run();
  return rowToProgressItem({
    series_slug: series.slug,
    episode_slug: episode.slug,
    percent,
    updated_at: updatedAt,
  }, series, episode);
}

export const PROGRESS_JSON_HEADERS = progressHeaders();
