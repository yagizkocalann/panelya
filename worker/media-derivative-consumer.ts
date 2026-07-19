import { MEDIA_DERIVATIVE_TASK_VERSION, parseMediaDerivativeTask, RESPONSIVE_WIDTHS } from "../app/lib/media/derivative-dispatch";
import { inspectDerivative } from "../app/lib/media/image-validation";

type ConsumerEnvironment = {
  DB: D1Database;
  MEDIA: {
    get(key: string): Promise<{ body: ReadableStream<Uint8Array> } | null>;
    put(key: string, value: ArrayBuffer, options?: { httpMetadata?: { contentType?: string } }): Promise<unknown>;
    delete(key: string): Promise<void>;
  };
  IMAGES: {
    input(stream: ReadableStream): {
      transform(options: Record<string, unknown>): {
        output(options: { format: string; quality: number }): Promise<{ response(): Response }>;
      };
    };
  };
};

type JobSourceRow = {
  job_id: string;
  asset_id: string;
  target_width: number;
  status: "queued" | "processing" | "completed" | "failed";
  updated_at: number;
  source_width: number;
  source_height: number;
  source_storage_key: string;
};

export type MediaDerivativeConsumeResult = "ack" | "retry";

function expectedHeight(sourceWidth: number, sourceHeight: number, targetWidth: number) {
  return Math.max(1, Math.round((sourceHeight * targetWidth) / sourceWidth));
}

async function failJob(db: D1Database, jobId: string, message: string) {
  await db.prepare(`UPDATE media_derivative_jobs SET status = 'failed', error = ?, updated_at = ?
    WHERE id = ? AND status = 'processing'`).bind(message.slice(0, 300), Date.now(), jobId).run();
}

export async function consumeMediaDerivativeTask(value: unknown, env: ConsumerEnvironment): Promise<MediaDerivativeConsumeResult> {
  const task = parseMediaDerivativeTask(value);
  if (!task || task.version !== MEDIA_DERIVATIVE_TASK_VERSION) return "ack";

  const row = await env.DB.prepare(`SELECT j.id AS job_id, j.asset_id, j.target_width, j.status, j.updated_at,
    a.width AS source_width, a.height AS source_height, a.storage_key AS source_storage_key
    FROM media_derivative_jobs j JOIN media_assets a ON a.id = j.asset_id WHERE j.id = ?`)
    .bind(task.jobId).first<JobSourceRow>();
  if (!row) return "ack";

  const targetHeight = expectedHeight(Number(row.source_width), Number(row.source_height), Number(row.target_width));
  const taskMatches = row.asset_id === task.assetId
    && Number(row.target_width) === task.targetWidth
    && targetHeight === task.targetHeight
    && RESPONSIVE_WIDTHS.includes(task.targetWidth as (typeof RESPONSIVE_WIDTHS)[number]);
  if (!taskMatches) {
    await env.DB.prepare(`UPDATE media_derivative_jobs SET status = 'failed', error = 'Kuyruk görevi iş kaydıyla eşleşmiyor.', updated_at = ?
      WHERE id = ? AND status != 'completed'`).bind(Date.now(), row.job_id).run();
    return "ack";
  }

  const existing = await env.DB.prepare("SELECT id FROM media_variants WHERE asset_id = ? AND width = ? AND mime_type = 'image/webp'")
    .bind(row.asset_id, row.target_width).first<{ id: string }>();
  if (existing) {
    await env.DB.prepare("UPDATE media_derivative_jobs SET status = 'completed', error = NULL, completed_at = COALESCE(completed_at, ?), updated_at = ? WHERE id = ?")
      .bind(Date.now(), Date.now(), row.job_id).run();
    return "ack";
  }
  if (row.status === "processing") {
    if (Number(row.updated_at) >= Date.now() - 10 * 60 * 1000) return "retry";
    await env.DB.prepare("UPDATE media_derivative_jobs SET status = 'failed', error = 'Üretim worker işlemi zaman aşımına uğradı; iş yeniden denenecek.', updated_at = ? WHERE id = ? AND status = 'processing'")
      .bind(Date.now(), row.job_id).run();
  }
  if (row.status === "completed") {
    await env.DB.prepare("UPDATE media_derivative_jobs SET status = 'failed', error = 'Tamamlanan işin varyant kaydı bulunamadı; iş yeniden denenecek.', updated_at = ? WHERE id = ? AND status = 'completed'")
      .bind(Date.now(), row.job_id).run();
  }

  const startedAt = Date.now();
  const claim = await env.DB.prepare(`UPDATE media_derivative_jobs SET status = 'processing', attempts = attempts + 1,
    error = NULL, started_at = ?, completed_at = NULL, updated_at = ?
    WHERE id = ? AND status IN ('queued','failed')`).bind(startedAt, startedAt, row.job_id).run();
  if (Number(claim.meta.changes ?? 0) !== 1) return "retry";

  let derivativeKey: string | null = null;
  try {
    const source = await env.MEDIA.get(row.source_storage_key);
    if (!source?.body) throw new Error("Kaynak medya bulunamadı.");
    const transformed = await env.IMAGES.input(source.body)
      .transform({ width: task.targetWidth, fit: "scale-down" })
      .output({ format: "image/webp", quality: 82 });
    const response = await transformed.response();
    if (!response.ok) throw new Error("Görsel dönüştürme servisi yanıt vermedi.");
    const body = await response.arrayBuffer();
    const metadata = await inspectDerivative(new File([body], `${task.assetId}-${task.targetWidth}w.webp`, { type: "image/webp" }), task.targetWidth, task.targetHeight);
    const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", body));
    const hash = Array.from(digest.slice(0, 12), (item) => item.toString(16).padStart(2, "0")).join("");
    derivativeKey = `media/derivatives/${task.assetId}/${task.targetWidth}w-${hash}.webp`;
    await env.MEDIA.put(derivativeKey, body, { httpMetadata: { contentType: metadata.mimeType } });
    const completedAt = Date.now();
    await env.DB.batch([
      env.DB.prepare(`INSERT OR IGNORE INTO media_variants (id, asset_id, storage_key, mime_type, byte_size, width, height, created_at)
        VALUES (?, ?, ?, 'image/webp', ?, ?, ?, ?)`).bind(crypto.randomUUID(), task.assetId, derivativeKey, metadata.byteSize, metadata.width, metadata.height, completedAt),
      env.DB.prepare("UPDATE media_derivative_jobs SET status = 'completed', error = NULL, completed_at = ?, updated_at = ? WHERE id = ? AND status = 'processing'")
        .bind(completedAt, completedAt, task.jobId),
      env.DB.prepare("INSERT INTO audit_events (id, user_id, action, metadata, created_at) VALUES (?, NULL, 'media.derivative_worker_completed', ?, ?)")
        .bind(crypto.randomUUID(), JSON.stringify({ jobId: task.jobId, mediaId: task.assetId, width: metadata.width, height: metadata.height, byteSize: metadata.byteSize }), completedAt),
    ]);
    return "ack";
  } catch {
    if (derivativeKey) await env.MEDIA.delete(derivativeKey).catch(() => undefined);
    await failJob(env.DB, task.jobId, "Üretim worker’ı responsive varyantı tamamlayamadı; iş yeniden denenecek.");
    return "retry";
  }
}
