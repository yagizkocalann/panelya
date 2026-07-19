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
  const episode = series.episodes.find((item) => item.slug === episodeSlug);
  if (!episode) return redirectTo(request, withMessage(returnTo, "error", "Bölüm bulunamadı."));
  const panels = [...episode.panels];
  if (action === "panel_move_many" || action === "panel_move_many_down" || action === "panel_remove_many") {
    const panelIds = Array.from(new Set(form.getAll("panel_ids").map((value) => String(value).trim()).filter((value) => value.length > 0 && value.length <= 140))).slice(0, 200);
    if (!panelIds.length || panelIds.some((id) => !panels.some((panel) => panel.id === id))) {
      return redirectTo(request, withMessage(returnTo, "error", "Toplu işlem seçimi geçersiz veya artık güncel değil."));
    }
    const selected = new Set(panelIds);
    if (action === "panel_remove_many") {
      if (form.get("bulk_confirmed") !== "yes") {
        return redirectTo(request, withMessage(returnTo, "error", "Toplu bağlantı kaldırma işlemini açıkça onayla."));
      }
      const selectedPanels = panels.filter((panel) => selected.has(panel.id));
      if (selectedPanels.some((panel) => !panel.image?.src.startsWith("/api/media/"))) {
        return redirectTo(request, withMessage(returnTo, "error", "Yalnız Studio üzerinden yüklenen medya panelleri toplu kaldırılabilir."));
      }
      if (panels.length - selectedPanels.length < 1) {
        return redirectTo(request, withMessage(returnTo, "error", "Bölümde en az bir panel kalmalıdır."));
      }
      const remainingPanels = panels.filter((panel) => !selected.has(panel.id));
      await db.prepare("UPDATE content_episodes SET panels_json = ?, updated_at = ? WHERE series_slug = ? AND slug = ?")
        .bind(JSON.stringify(remainingPanels), now, seriesSlug, episodeSlug).run();
      await writeAudit(user.id, "media.panels_unlinked", { seriesSlug, episodeSlug, count: selectedPanels.length });
      return redirectTo(request, withMessage(returnTo, "saved", "panels"));
    }

    const direction = action === "panel_move_many" ? "up" : "down";
    let changed = false;
    if (direction === "up") {
      for (let index = 1; index < panels.length; index += 1) {
        if (selected.has(panels[index].id) && !selected.has(panels[index - 1].id)) {
          [panels[index - 1], panels[index]] = [panels[index], panels[index - 1]];
          changed = true;
        }
      }
    } else {
      for (let index = panels.length - 2; index >= 0; index -= 1) {
        if (selected.has(panels[index].id) && !selected.has(panels[index + 1].id)) {
          [panels[index], panels[index + 1]] = [panels[index + 1], panels[index]];
          changed = true;
        }
      }
    }
    if (!changed) return redirectTo(request, withMessage(returnTo, "error", `Seçili paneller ${direction === "up" ? "daha yukarı" : "daha aşağı"} taşınamaz.`));
    await db.prepare("UPDATE content_episodes SET panels_json = ?, updated_at = ? WHERE series_slug = ? AND slug = ?")
      .bind(JSON.stringify(panels), now, seriesSlug, episodeSlug).run();
    await writeAudit(user.id, "media.panels_reordered", { seriesSlug, episodeSlug, count: panelIds.length, direction });
    return redirectTo(request, withMessage(returnTo, "saved", "panels"));
  }

  const panelId = field(form, "panel_id", 140);
  const index = panels.findIndex((panel) => panel.id === panelId);
  if (index < 0) return redirectTo(request, withMessage(returnTo, "error", "Panel artık bu bölümde değil."));

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
