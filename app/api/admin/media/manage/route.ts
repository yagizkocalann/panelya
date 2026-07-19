import { assertSameOrigin, getCurrentUser } from "../../../../lib/auth";
import { redirectTo } from "../../../../lib/auth-http";
import { getStudioSeries } from "../../../../lib/content-repository";
import { getDatabase, writeAudit } from "../../../../lib/database";
import { getMediaAsset } from "../../../../lib/media/repository";
import { isStudioRequest } from "../../../../lib/site-origins";

function field(form: FormData, name: string, max = 160) {
  return String(form.get(name) ?? "").trim().slice(0, max);
}

function safeReturnTo(form: FormData) {
  const value = field(form, "return_to", 300);
  return /^\/(?:content|media)(?:[/?]|$)/.test(value) ? value : "/media";
}

function withMessage(path: string, key: "saved" | "error" | "restored", value: string) {
  const url = new URL(path, "http://studio.localhost");
  url.searchParams.set(key, value);
  return `${url.pathname}${url.search}`;
}

export async function POST(request: Request) {
  if (!isStudioRequest(request)) return new Response("Not found", { status: 404 });
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, "/login?return_to=/media");
  if (user.role !== "admin") return new Response("Yetkisiz.", { status: 403 });

  const form = await request.formData();
  const action = field(form, "action", 40);
  const seriesSlug = field(form, "series_slug", 80);
  const returnTo = safeReturnTo(form);
  const series = seriesSlug ? await getStudioSeries(seriesSlug) : null;
  if (!series) return redirectTo(request, withMessage(returnTo, "error", "Seri bulunamadı."));

  const db = await getDatabase();
  const now = Date.now();
  if (action === "cover_restore") {
    const mediaId = field(form, "media_id", 80);
    const asset = await getMediaAsset(mediaId);
    if (!asset || asset.kind !== "cover" || asset.seriesSlug !== seriesSlug) {
      return redirectTo(request, withMessage(returnTo, "error", "Kapak geçmişi kaydı geçersiz."));
    }
    await db.prepare("UPDATE content_series SET cover_image = ?, updated_at = ? WHERE slug = ?")
      .bind(`/api/media/${asset.id}`, now, seriesSlug).run();
    await writeAudit(user.id, "media.cover_restored", { mediaId: asset.id, seriesSlug });
    return redirectTo(request, withMessage(returnTo, "restored", asset.id));
  }

  const episodeSlug = field(form, "episode_slug", 80);
  const panelId = field(form, "panel_id", 140);
  const episode = series.episodes.find((item) => item.slug === episodeSlug);
  if (!episode) return redirectTo(request, withMessage(returnTo, "error", "Bölüm bulunamadı."));
  const index = episode.panels.findIndex((panel) => panel.id === panelId);
  if (index < 0) return redirectTo(request, withMessage(returnTo, "error", "Panel artık bu bölümde değil."));

  const panels = [...episode.panels];
  if (action === "panel_move") {
    const direction = field(form, "direction", 10);
    const target = direction === "up" ? index - 1 : direction === "down" ? index + 1 : -1;
    if (target < 0 || target >= panels.length) {
      return redirectTo(request, withMessage(returnTo, "error", "Panel bu yönde taşınamaz."));
    }
    [panels[index], panels[target]] = [panels[target], panels[index]];
    await db.prepare("UPDATE content_episodes SET panels_json = ?, updated_at = ? WHERE series_slug = ? AND slug = ?")
      .bind(JSON.stringify(panels), now, seriesSlug, episodeSlug).run();
    await writeAudit(user.id, "media.panel_reordered", { seriesSlug, episodeSlug, panelId, from: index, to: target });
    return redirectTo(request, withMessage(returnTo, "saved", "panels"));
  }

  if (action === "panel_remove") {
    const panel = panels[index];
    if (!panel.image?.src.startsWith("/api/media/")) {
      return redirectTo(request, withMessage(returnTo, "error", "Yalnız Studio üzerinden yüklenen medya panelleri kaldırılabilir."));
    }
    if (panels.length <= 1) {
      return redirectTo(request, withMessage(returnTo, "error", "Bölümde en az bir panel kalmalıdır."));
    }
    panels.splice(index, 1);
    await db.prepare("UPDATE content_episodes SET panels_json = ?, updated_at = ? WHERE series_slug = ? AND slug = ?")
      .bind(JSON.stringify(panels), now, seriesSlug, episodeSlug).run();
    await writeAudit(user.id, "media.panel_unlinked", { seriesSlug, episodeSlug, panelId, mediaUrl: panel.image.src, position: index });
    return redirectTo(request, withMessage(returnTo, "saved", "panels"));
  }

  return redirectTo(request, withMessage(returnTo, "error", "Medya işlemi tanınmıyor."));
}
