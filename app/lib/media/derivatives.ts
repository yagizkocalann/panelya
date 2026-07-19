import { getDatabase } from "../database";
import { mediaDerivativeDispatchMode, type MediaDerivativeDispatchMode } from "../runtime-config";
import { createMediaDerivativeTask, getMediaDerivativeDispatcher, RESPONSIVE_WIDTHS } from "./derivative-dispatch";
import type { MediaAsset } from "./repository";

export { RESPONSIVE_WIDTHS } from "./derivative-dispatch";
export type DerivativeJobStatus = "queued" | "processing" | "completed" | "failed";
export type DerivativeDispatchStatus = "local" | "pending" | "sent" | "failed";

export type MediaDerivativeJob = {
  id: string;
  assetId: string;
  targetWidth: number;
  targetHeight: number;
  status: DerivativeJobStatus;
  attempts: number;
  error: string | null;
  dispatchMode: MediaDerivativeDispatchMode;
  dispatchStatus: DerivativeDispatchStatus;
  dispatchAttempts: number;
  dispatchError: string | null;
  dispatchedAt: number | null;
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
  dispatch_mode: MediaDerivativeDispatchMode;
  dispatch_status: DerivativeDispatchStatus;
  dispatch_attempts: number;
  dispatch_error: string | null;
  dispatched_at: number | null;
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
    dispatchMode: row.dispatch_mode,
    dispatchStatus: row.dispatch_status,
    dispatchAttempts: Number(row.dispatch_attempts),
    dispatchError: row.dispatch_error,
    dispatchedAt: row.dispatched_at === null ? null : Number(row.dispatched_at),
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

async function dispatchDerivativeJobs(jobs: MediaDerivativeJob[]) {
  if (!jobs.length) return { sent: 0, failed: 0 };
  const db = await getDatabase();
  let dispatcher;
  try {
    dispatcher = await getMediaDerivativeDispatcher();
  } catch {
    const failedAt = Date.now();
    await db.batch(jobs.map((job) => db.prepare(`UPDATE media_derivative_jobs
      SET dispatch_status = 'failed', dispatch_attempts = dispatch_attempts + 1,
      dispatch_error = 'Üretim kuyruğu yapılandırması kullanılamıyor.', updated_at = ?
      WHERE id = ? AND dispatch_mode = 'cloudflare_queue'
      AND (dispatch_status IN ('pending','failed') OR (dispatch_status = 'sent' AND status = 'failed'))`)
      .bind(failedAt, job.id)));
    return { sent: 0, failed: jobs.length };
  }
  if (!dispatcher.sendsExternally) return { sent: 0, failed: 0 };

  let sent = 0;
  let failed = 0;
  for (const job of jobs) {
    const attemptAt = Date.now();
    const claimed = await db.prepare(`UPDATE media_derivative_jobs
      SET dispatch_status = 'pending', dispatch_attempts = dispatch_attempts + 1, dispatch_error = NULL, updated_at = ?
      WHERE id = ? AND dispatch_mode = 'cloudflare_queue'
      AND (dispatch_status IN ('pending','failed') OR (dispatch_status = 'sent' AND status = 'failed'))
      AND status IN ('queued','failed')`)
      .bind(attemptAt, job.id).run();
    if (Number(claimed.meta.changes ?? 0) !== 1) continue;
    try {
      await dispatcher.send(createMediaDerivativeTask({ jobId: job.id, assetId: job.assetId, targetWidth: job.targetWidth, targetHeight: job.targetHeight }));
      const dispatchedAt = Date.now();
      await db.prepare(`UPDATE media_derivative_jobs SET dispatch_status = 'sent', dispatch_error = NULL, dispatched_at = ?, updated_at = ? WHERE id = ?`)
        .bind(dispatchedAt, dispatchedAt, job.id).run();
      sent += 1;
    } catch {
      await db.prepare(`UPDATE media_derivative_jobs SET dispatch_status = 'failed',
        dispatch_error = 'Üretim kuyruğuna teslim edilemedi; yeniden gönderilebilir.', updated_at = ? WHERE id = ?`)
        .bind(Date.now(), job.id).run();
      failed += 1;
    }
  }
  return { sent, failed };
}

export async function enqueueDerivativeJobs(asset: Pick<MediaAsset, "id" | "width" | "height">, now = Date.now()) {
  const widths = RESPONSIVE_WIDTHS.filter((width) => width < asset.width);
  if (!widths.length) return { queued: 0, sent: 0, dispatchFailed: 0 };
  const configuredMode = await mediaDerivativeDispatchMode();
  if (configuredMode !== "local_browser" && configuredMode !== "cloudflare_queue") {
    throw new Error("Unsupported media derivative dispatch mode.");
  }
  const dispatchMode: MediaDerivativeDispatchMode = configuredMode;
  const db = await getDatabase();
  const drafts = widths.map((width) => ({ id: crypto.randomUUID(), width }));
  const results = await db.batch(drafts.map((job) => db.prepare(`INSERT OR IGNORE INTO media_derivative_jobs
    (id, asset_id, target_width, format, status, attempts, error, dispatch_mode, dispatch_status,
      dispatch_attempts, dispatch_error, dispatched_at, created_at, started_at, completed_at, updated_at)
    VALUES (?, ?, ?, 'webp', 'queued', 0, NULL, ?, ?, 0, NULL, NULL, ?, NULL, NULL, ?)`)
    .bind(job.id, asset.id, job.width, dispatchMode, dispatchMode === "local_browser" ? "local" : "pending", now, now)));
  const inserted = drafts.filter((_, index) => Number(results[index]?.meta.changes ?? 0) === 1).map((job) => ({
    id: job.id,
    assetId: asset.id,
    targetWidth: job.width,
    targetHeight: targetHeight(asset.width, asset.height, job.width),
    status: "queued" as const,
    attempts: 0,
    error: null,
    dispatchMode,
    dispatchStatus: dispatchMode === "local_browser" ? "local" as const : "pending" as const,
    dispatchAttempts: 0,
    dispatchError: null,
    dispatchedAt: null,
    sourceWidth: asset.width,
    sourceHeight: asset.height,
    filename: "",
    createdAt: now,
    updatedAt: now,
  }));
  const dispatch = dispatchMode === "cloudflare_queue" ? await dispatchDerivativeJobs(inserted) : { sent: 0, failed: 0 };
  return { queued: inserted.length, sent: dispatch.sent, dispatchFailed: dispatch.failed };
}

export async function listDerivativeJobs(limit = 60) {
  const db = await getDatabase();
  const staleBefore = Date.now() - 10 * 60 * 1000;
  await db.prepare(`UPDATE media_derivative_jobs SET status = 'failed', error = 'İşlemci zaman aşımına uğradı; yeniden denenebilir.', updated_at = ?
    WHERE status = 'processing' AND updated_at < ?`).bind(Date.now(), staleBefore).run();
  const rows = await db.prepare(`SELECT j.id, j.asset_id, j.target_width, j.status, j.attempts, j.error,
    j.dispatch_mode, j.dispatch_status, j.dispatch_attempts, j.dispatch_error, j.dispatched_at,
    j.created_at, j.updated_at, a.width AS source_width, a.height AS source_height, a.original_filename
    FROM media_derivative_jobs j JOIN media_assets a ON a.id = j.asset_id
    ORDER BY CASE j.status WHEN 'failed' THEN 0 WHEN 'queued' THEN 1 WHEN 'processing' THEN 2 ELSE 3 END, j.created_at ASC
    LIMIT ?`).bind(Math.max(1, Math.min(limit, 200))).all<JobRow>();
  return rows.results.map(fromJobRow);
}

export async function getDerivativeJob(id: string) {
  const db = await getDatabase();
  const row = await db.prepare(`SELECT j.id, j.asset_id, j.target_width, j.status, j.attempts, j.error,
    j.dispatch_mode, j.dispatch_status, j.dispatch_attempts, j.dispatch_error, j.dispatched_at,
    j.created_at, j.updated_at, a.width AS source_width, a.height AS source_height, a.original_filename
    FROM media_derivative_jobs j JOIN media_assets a ON a.id = j.asset_id WHERE j.id = ?`).bind(id).first<JobRow>();
  return row ? fromJobRow(row) : null;
}

export async function redispatchDerivativeJobs(limit = 60) {
  const mode = await mediaDerivativeDispatchMode();
  if (mode !== "cloudflare_queue") throw new Error("Üretim kuyruğu etkin değil.");
  const jobs = (await listDerivativeJobs(limit)).filter((job) =>
    job.dispatchMode === "cloudflare_queue"
    && (job.dispatchStatus === "pending" || job.dispatchStatus === "failed" || (job.dispatchStatus === "sent" && job.status === "failed"))
    && (job.status === "queued" || job.status === "failed"));
  return dispatchDerivativeJobs(jobs);
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
