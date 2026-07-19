import { assertSameOrigin, getCurrentUser } from "../../../lib/auth";
import { redirectTo } from "../../../lib/auth-http";
import { getStudioSeries } from "../../../lib/content-repository";
import { getDatabase, writeAudit } from "../../../lib/database";
import { extensionForMime, inspectImage, type MediaKind } from "../../../lib/media/image-validation";
import { enqueueDerivativeJobs } from "../../../lib/media/derivatives";
import { createMediaAsset } from "../../../lib/media/repository";
import { getMediaStorage } from "../../../lib/media/storage";
import { isStudioRequest } from "../../../lib/site-origins";

function field(form: FormData, name: string, max = 120) { return String(form.get(name) ?? "").trim().slice(0, max); }
function errorRedirect(request: Request, message: string) { return redirectTo(request, `/media?error=${encodeURIComponent(message)}`); }

export async function POST(request: Request) {
  if (!isStudioRequest(request)) return new Response("Not found", { status: 404 });
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, "/login?return_to=/media");
  if (user.role !== "admin") return new Response("Yetkisiz.", { status: 403 });

  const form = await request.formData();
  const kind = form.get("kind") === "panel" ? "panel" : form.get("kind") === "cover" ? "cover" : null;
  const seriesSlug = field(form, "series_slug", 80);
  const episodeSlug = field(form, "episode_slug", 80);
  const file = form.get("file");
  if (!kind || !seriesSlug || !(file instanceof File)) return errorRedirect(request, "Dosya, tür ve seri seçimi zorunludur.");

  const series = await getStudioSeries(seriesSlug);
  if (!series) return errorRedirect(request, "Seçilen seri bulunamadı.");
  const episode = kind === "panel" ? series.episodes.find((item) => item.slug === episodeSlug) : undefined;
  if (kind === "panel" && !episode) return errorRedirect(request, "Panel için geçerli bir bölüm seçin.");

  try {
    const metadata = await inspectImage(file, kind as MediaKind);
    const body = await file.arrayBuffer();
    const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", body));
    const hash = Array.from(digest.slice(0, 12), (item) => item.toString(16).padStart(2, "0")).join("");
    const id = crypto.randomUUID();
    const storageKey = `media/${kind}/${new Date().getUTCFullYear()}/${hash}-${id}.${extensionForMime(metadata.mimeType)}`;
    const storage = await getMediaStorage();
    const db = await getDatabase();
    await storage.put(storageKey, body, { contentType: metadata.mimeType });
    const now = Date.now();
    try {
      await createMediaAsset({ id, storageKey, originalFilename: file.name.slice(0, 180) || `upload.${extensionForMime(metadata.mimeType)}`, ...metadata, kind, seriesSlug, episodeSlug: kind === "panel" ? episodeSlug : null, createdByUserId: user.id, createdAt: now });
      if (kind === "cover") {
        await db.prepare("UPDATE content_series SET cover_image = ?, updated_at = ? WHERE slug = ?").bind(`/api/media/${id}`, now, seriesSlug).run();
      } else {
        const panel = { id: `media-${id}`, scene: "Studio üzerinden yüklenen özgün görsel panel.", tone: series.tone, image: { src: `/api/media/${id}`, alt: `${series.title} — ${episode?.title ?? "panel"}`, width: metadata.width, height: metadata.height } };
        await db.prepare("UPDATE content_episodes SET panels_json = ?, updated_at = ? WHERE series_slug = ? AND slug = ?")
          .bind(JSON.stringify([...episode!.panels, panel]), now, seriesSlug, episodeSlug).run();
      }
      await writeAudit(user.id, "media.uploaded", { mediaId: id, kind, seriesSlug, episodeSlug: kind === "panel" ? episodeSlug : null, mimeType: metadata.mimeType, byteSize: metadata.byteSize, width: metadata.width, height: metadata.height });
    } catch (error) {
      await Promise.allSettled([
        storage.delete(storageKey),
        db.prepare("DELETE FROM media_assets WHERE id = ?").bind(id).run(),
      ]);
      throw error;
    }
    try {
      const queued = await enqueueDerivativeJobs({ id, width: metadata.width });
      await writeAudit(user.id, "media.derivatives_queued", { mediaId: id, jobs: queued });
    } catch {
      await writeAudit(user.id, "media.derivatives_enqueue_failed", { mediaId: id }).catch(() => undefined);
    }
    return redirectTo(request, `/media?uploaded=${id}`);
  } catch (error) {
    return errorRedirect(request, error instanceof Error ? error.message : "Yükleme tamamlanamadı.");
  }
}
