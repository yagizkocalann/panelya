import { getDatabase } from "../database";
import type { MediaAsset } from "./repository";

export const RESPONSIVE_WIDTHS = [480, 768, 1200] as const;
export type DerivativeJobStatus = "queued" | "processing" | "completed" | "failed";

export type MediaDerivativeJob = {
  id: string;
  assetId: string;
  targetWidth: number;
  targetHeight: number;
  status: DerivativeJobStatus;
  attempts: number;
  error: string | null;
  sourceWidth: number;
  sourceHeight: number;
  filename: string;
  createdAt: number;
  updatedAt: number;
};

type JobRow = {
  id: string;
  asset_id: string;
  target_width: number;
  status: DerivativeJobStatus;
  attempts: number;
  error: string | null;
  source_width: number;
  source_height: number;
  original_filename: string;
  created_at: number;
  updated_at: number;
};

export type MediaVariant = {
  id: string;
  assetId: string;
  storageKey: string;
  mimeType: "image/webp";
  byteSize: number;
  width: number;
  height: number;
  createdAt: number;
};

type VariantRow = {
  id: string;
  asset_id: string;
  storage_key: string;
  mime_type: "image/webp";
  byte_size: number;
  width: number;
  height: number;
  created_at: number;
};

function targetHeight(sourceWidth: number, sourceHeight: number, width: number) {
  return Math.max(1, Math.round((sourceHeight * width) / sourceWidth));
}

function fromJobRow(row: JobRow): MediaDerivativeJob {
  return {
    id: row.id,
    assetId: row.asset_id,
    targetWidth: Number(row.target_width),
    targetHeight: targetHeight(Number(row.source_width), Number(row.source_height), Number(row.target_width)),
    status: row.status,
    attempts: Number(row.attempts),
    error: row.error,
    sourceWidth: Number(row.source_width),
    sourceHeight: Number(row.source_height),
    filename: row.original_filename,
    createdAt: Number(row.created_at),
    updatedAt: Number(row.updated_at),
  };
}

function fromVariantRow(row: VariantRow): MediaVariant {
  return { id: row.id, assetId: row.asset_id, storageKey: row.storage_key, mimeType: row.mime_type, byteSize: Number(row.byte_size), width: Number(row.width), height: Number(row.height), createdAt: Number(row.created_at) };
}

export async function enqueueDerivativeJobs(asset: Pick<MediaAsset, "id" | "width">, now = Date.now()) {
  const widths = RESPONSIVE_WIDTHS.filter((width) => width < asset.width);
  if (!widths.length) return 0;
  const db = await getDatabase();
  await db.batch(widths.map((width) => db.prepare(`INSERT OR IGNORE INTO media_derivative_jobs
    (id, asset_id, target_width, format, status, attempts, error, created_at, started_at, completed_at, updated_at)
    VALUES (?, ?, ?, 'webp', 'queued', 0, NULL, ?, NULL, NULL, ?)`)
    .bind(crypto.randomUUID(), asset.id, width, now, now)));
  return widths.length;
}

export async function listDerivativeJobs(limit = 60) {
  const db = await getDatabase();
  const staleBefore = Date.now() - 10 * 60 * 1000;
  await db.prepare(`UPDATE media_derivative_jobs SET status = 'failed', error = 'İşlemci zaman aşımına uğradı; yeniden denenebilir.', updated_at = ?
    WHERE status = 'processing' AND updated_at < ?`).bind(Date.now(), staleBefore).run();
  const rows = await db.prepare(`SELECT j.id, j.asset_id, j.target_width, j.status, j.attempts, j.error,
    j.created_at, j.updated_at, a.width AS source_width, a.height AS source_height, a.original_filename
    FROM media_derivative_jobs j JOIN media_assets a ON a.id = j.asset_id
    ORDER BY CASE j.status WHEN 'failed' THEN 0 WHEN 'queued' THEN 1 WHEN 'processing' THEN 2 ELSE 3 END, j.created_at ASC
    LIMIT ?`).bind(Math.max(1, Math.min(limit, 200))).all<JobRow>();
  return rows.results.map(fromJobRow);
}

export async function getDerivativeJob(id: string) {
  const db = await getDatabase();
  const row = await db.prepare(`SELECT j.id, j.asset_id, j.target_width, j.status, j.attempts, j.error,
    j.created_at, j.updated_at, a.width AS source_width, a.height AS source_height, a.original_filename
    FROM media_derivative_jobs j JOIN media_assets a ON a.id = j.asset_id WHERE j.id = ?`).bind(id).first<JobRow>();
  return row ? fromJobRow(row) : null;
}

export async function getMediaVariant(assetId: string, width: number) {
  if (!RESPONSIVE_WIDTHS.includes(width as (typeof RESPONSIVE_WIDTHS)[number])) return null;
  const db = await getDatabase();
  const row = await db.prepare("SELECT * FROM media_variants WHERE asset_id = ? AND width = ? AND mime_type = 'image/webp'").bind(assetId, width).first<VariantRow>();
  return row ? fromVariantRow(row) : null;
}

export async function listVariantCounts() {
  const db = await getDatabase();
  const rows = await db.prepare("SELECT asset_id, COUNT(*) AS count FROM media_variants GROUP BY asset_id").all<{ asset_id: string; count: number }>();
  return new Map(rows.results.map((row) => [row.asset_id, Number(row.count)]));
}
