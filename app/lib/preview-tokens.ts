import { getDatabase } from "./database";

const PREVIEW_TTL_MS = 30 * 60 * 1000;

export type PreviewGrant = {
  id: string;
  seriesSlug: string;
  episodeSlug: string | null;
  createdByUserId: string | null;
  expiresAt: number;
  revokedAt: number | null;
  createdAt: number;
  active: boolean;
};

type PreviewGrantRow = {
  id: string;
  series_slug: string;
  episode_slug: string | null;
  created_by_user_id: string | null;
  expires_at: number;
  revoked_at: number | null;
  created_at: number;
};

function fromRow(row: PreviewGrantRow): PreviewGrant {
  return {
    id: row.id,
    seriesSlug: row.series_slug,
    episodeSlug: row.episode_slug,
    createdByUserId: row.created_by_user_id,
    expiresAt: Number(row.expires_at),
    revokedAt: row.revoked_at === null ? null : Number(row.revoked_at),
    createdAt: Number(row.created_at),
    active: row.revoked_at === null && Number(row.expires_at) > Date.now(),
  };
}

function randomToken() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

async function tokenHash(rawToken: string) {
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(rawToken)));
  return Array.from(digest, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

export async function createPreviewGrant(userId: string, seriesSlug: string, episodeSlug: string | null) {
  const rawToken = randomToken();
  const now = Date.now();
  const grant: PreviewGrant = {
    id: crypto.randomUUID(),
    seriesSlug,
    episodeSlug,
    createdByUserId: userId,
    expiresAt: now + PREVIEW_TTL_MS,
    revokedAt: null,
    createdAt: now,
    active: true,
  };
  const db = await getDatabase();
  await db.prepare(`INSERT INTO preview_tokens (id, token_hash, series_slug, episode_slug, created_by_user_id, expires_at, revoked_at, created_at)
    VALUES (?, ?, ?, ?, ?, ?, NULL, ?)`).bind(
      grant.id,
      await tokenHash(rawToken),
      seriesSlug,
      episodeSlug,
      userId,
      grant.expiresAt,
      grant.createdAt,
    ).run();
  return { rawToken, grant };
}

export async function resolvePreviewGrant(rawToken: string) {
  if (!/^[A-Za-z0-9_-]{43}$/.test(rawToken)) return null;
  const db = await getDatabase();
  const row = await db.prepare(`SELECT id, series_slug, episode_slug, created_by_user_id, expires_at, revoked_at, created_at
    FROM preview_tokens WHERE token_hash = ? AND revoked_at IS NULL AND expires_at > ?`).bind(
      await tokenHash(rawToken),
      Date.now(),
    ).first<PreviewGrantRow>();
  return row ? fromRow(row) : null;
}

export async function listPreviewGrants(seriesSlug: string, episodeSlug: string | null) {
  const db = await getDatabase();
  const rows = await db.prepare(`SELECT id, series_slug, episode_slug, created_by_user_id, expires_at, revoked_at, created_at
    FROM preview_tokens
    WHERE series_slug = ? AND ((episode_slug = ?) OR (episode_slug IS NULL AND ? IS NULL))
    ORDER BY created_at DESC LIMIT 20`).bind(seriesSlug, episodeSlug, episodeSlug).all<PreviewGrantRow>();
  return rows.results.map(fromRow);
}

export async function revokePreviewGrant(id: string, seriesSlug: string, episodeSlug: string | null) {
  const db = await getDatabase();
  const result = await db.prepare(`UPDATE preview_tokens SET revoked_at = ?
    WHERE id = ? AND series_slug = ? AND ((episode_slug = ?) OR (episode_slug IS NULL AND ? IS NULL)) AND revoked_at IS NULL`)
    .bind(Date.now(), id, seriesSlug, episodeSlug, episodeSlug).run();
  return Number(result.meta.changes ?? 0) > 0;
}
