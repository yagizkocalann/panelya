import { getDatabase } from "../database";
import type { AllowedImageType, MediaKind } from "./image-validation";

export type MediaAsset = { id: string; storageKey: string; originalFilename: string; mimeType: AllowedImageType; byteSize: number; width: number; height: number; kind: MediaKind; seriesSlug: string; episodeSlug: string | null; createdByUserId: string | null; createdAt: number };
type MediaAssetRow = { id: string; storage_key: string; original_filename: string; mime_type: AllowedImageType; byte_size: number; width: number; height: number; kind: MediaKind; series_slug: string; episode_slug: string | null; created_by_user_id: string | null; created_at: number };
function fromRow(row: MediaAssetRow): MediaAsset { return { id: row.id, storageKey: row.storage_key, originalFilename: row.original_filename, mimeType: row.mime_type, byteSize: Number(row.byte_size), width: Number(row.width), height: Number(row.height), kind: row.kind, seriesSlug: row.series_slug, episodeSlug: row.episode_slug, createdByUserId: row.created_by_user_id, createdAt: Number(row.created_at) }; }

export async function createMediaAsset(asset: MediaAsset) { const db = await getDatabase(); await db.prepare(`INSERT INTO media_assets (id, storage_key, original_filename, mime_type, byte_size, width, height, kind, series_slug, episode_slug, created_by_user_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`).bind(asset.id, asset.storageKey, asset.originalFilename, asset.mimeType, asset.byteSize, asset.width, asset.height, asset.kind, asset.seriesSlug, asset.episodeSlug, asset.createdByUserId, asset.createdAt).run(); }
export async function getMediaAsset(id: string) { const db = await getDatabase(); const row = await db.prepare("SELECT * FROM media_assets WHERE id = ?").bind(id).first<MediaAssetRow>(); return row ? fromRow(row) : null; }
export async function listMediaAssets(limit = 100) { const db = await getDatabase(); const rows = await db.prepare("SELECT * FROM media_assets ORDER BY created_at DESC LIMIT ?").bind(Math.max(1, Math.min(limit, 200))).all<MediaAssetRow>(); return rows.results.map(fromRow); }
export async function isPublicMediaAsset(asset: MediaAsset) {
  const db = await getDatabase();
  if (asset.kind === "cover") return Boolean((await db.prepare("SELECT 1 AS visible FROM content_series WHERE slug = ? AND publication_status = 'published' AND cover_image = ?").bind(asset.seriesSlug, `/api/media/${asset.id}`).first<{ visible: number }>())?.visible);
  return Boolean((await db.prepare(`SELECT 1 AS visible FROM content_episodes e JOIN content_series s ON s.slug = e.series_slug WHERE e.series_slug = ? AND e.slug = ? AND e.publication_status = 'published' AND s.publication_status = 'published' AND instr(e.panels_json, ?) > 0`).bind(asset.seriesSlug, asset.episodeSlug, `/api/media/${asset.id}`).first<{ visible: number }>())?.visible);
}
