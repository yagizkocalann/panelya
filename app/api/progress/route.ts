import { getEpisode } from "../../data/catalog";
import { getPublishedSeries } from "../../lib/content-repository";
import { assertSameOrigin, getCurrentUser } from "../../lib/auth";
import { getDatabase } from "../../lib/database";

export async function POST(request: Request) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const user = await getCurrentUser();
  if (!user) return new Response(null, { status: 204 });
  const data = await request.json() as { seriesSlug?: string; episodeSlug?: string; percent?: number };
  const series = await getPublishedSeries(String(data.seriesSlug ?? ""));
  const episode = series && getEpisode(series, String(data.episodeSlug ?? ""));
  if (!series || !episode) return new Response("İçerik bulunamadı.", { status: 404 });
  const percent = Math.max(0, Math.min(100, Math.round(Number(data.percent) || 0)));
  const db = await getDatabase();
  await db.prepare(`INSERT INTO reading_progress (user_id, series_slug, episode_slug, episode_number, episode_title, percent, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(user_id, series_slug) DO UPDATE SET episode_slug = excluded.episode_slug, episode_number = excluded.episode_number, episode_title = excluded.episode_title, percent = excluded.percent, updated_at = excluded.updated_at`)
    .bind(user.id, series.slug, episode.slug, episode.number, episode.title, percent, Date.now()).run();
  return new Response(null, { status: 204 });
}
