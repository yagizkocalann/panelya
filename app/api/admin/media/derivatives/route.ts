import { assertSameOrigin, getCurrentUser } from "../../../../lib/auth";
import { getDatabase, writeAudit } from "../../../../lib/database";
import { getDerivativeJob, getMediaVariant } from "../../../../lib/media/derivatives";
import { inspectDerivative } from "../../../../lib/media/image-validation";
import { getMediaAsset } from "../../../../lib/media/repository";
import { getMediaStorage } from "../../../../lib/media/storage";
import { isStudioRequest } from "../../../../lib/site-origins";

function json(message: string, status: number, extra?: Record<string, unknown>) {
  return Response.json({ ok: status < 400, message, ...extra }, { status });
}

export async function POST(request: Request) {
  if (!isStudioRequest(request)) return new Response("Not found", { status: 404 });
  try { assertSameOrigin(request); } catch { return json("Geçersiz istek.", 403); }
  const user = await getCurrentUser();
  if (!user) return json("Oturum gerekli.", 401);
  if (user.role !== "admin") return json("Yetkisiz.", 403);

  const form = await request.formData();
  const jobId = String(form.get("job_id") ?? "").trim().slice(0, 80);
  const file = form.get("file");
  if (!jobId || !(file instanceof File)) return json("İş kimliği ve WebP dosyası zorunludur.", 400);

  const job = await getDerivativeJob(jobId);
  if (!job) return json("Türetme işi bulunamadı.", 404);
  const existing = await getMediaVariant(job.assetId, job.targetWidth);
  if (existing) return json("Varyant zaten hazır.", 200, { variant: existing });
  if (job.status === "processing") return json("Bu iş şu anda işleniyor.", 409);
  if (job.status === "completed") return json("Tamamlanan işin varyantı bulunamadı; iş yeniden kuyruğa alınmalı.", 409);

  const asset = await getMediaAsset(job.assetId);
  if (!asset) return json("Kaynak medya bulunamadı.", 404);

  const db = await getDatabase();
  const now = Date.now();
  const claim = await db.prepare(`UPDATE media_derivative_jobs SET status = 'processing', attempts = attempts + 1,
    error = NULL, started_at = ?, completed_at = NULL, updated_at = ?
    WHERE id = ? AND status IN ('queued','failed')`).bind(now, now, job.id).run();
  if (Number(claim.meta.changes ?? 0) !== 1) return json("İş başka bir işlemci tarafından alındı.", 409);

  let storageKey: string | null = null;
  try {
    const metadata = await inspectDerivative(file, job.targetWidth, job.targetHeight);
    const body = await file.arrayBuffer();
    const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", body));
    const hash = Array.from(digest.slice(0, 12), (item) => item.toString(16).padStart(2, "0")).join("");
    storageKey = `media/derivatives/${asset.id}/${job.targetWidth}w-${hash}.webp`;
    const storage = await getMediaStorage();
    await storage.put(storageKey, body, { contentType: metadata.mimeType });
    const variant = { id: crypto.randomUUID(), assetId: asset.id, storageKey, ...metadata, createdAt: Date.now() };
    try {
      await db.batch([
        db.prepare(`INSERT INTO media_variants (id, asset_id, storage_key, mime_type, byte_size, width, height, created_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)`).bind(variant.id, variant.assetId, variant.storageKey, variant.mimeType, variant.byteSize, variant.width, variant.height, variant.createdAt),
        db.prepare("UPDATE media_derivative_jobs SET status = 'completed', completed_at = ?, updated_at = ? WHERE id = ? AND status = 'processing'")
          .bind(variant.createdAt, variant.createdAt, job.id),
      ]);
    } catch (error) {
      await storage.delete(storageKey);
      throw error;
    }
    await writeAudit(user.id, "media.derivative_completed", { jobId: job.id, mediaId: asset.id, width: variant.width, height: variant.height, byteSize: variant.byteSize }).catch(() => undefined);
    return json("Responsive varyant hazır.", 200, { variant });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Responsive varyant üretilemedi.";
    await db.prepare("UPDATE media_derivative_jobs SET status = 'failed', error = ?, updated_at = ? WHERE id = ?")
      .bind(message.slice(0, 300), Date.now(), job.id).run();
    return json(message, 400);
  }
}
