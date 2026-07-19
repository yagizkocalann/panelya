import { assertSameOrigin, getCurrentUser } from "../../../../lib/auth";
import { redirectTo } from "../../../../lib/auth-http";
import { COPYRIGHT_NOTICE_STATUSES, type CopyrightNoticeStatus } from "../../../../lib/copyright-notices";
import { getDatabase, writeAudit } from "../../../../lib/database";
import { consumeRateLimit, requestFingerprint } from "../../../../lib/rate-limit";
import { isStudioRequest } from "../../../../lib/site-origins";

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  if (!isStudioRequest(request)) return new Response("Not found", { status: 404 });
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const actor = await getCurrentUser();
  if (!actor) return redirectTo(request, "/login?return_to=/messages");
  if (actor.role !== "admin") return new Response("Yetkisiz.", { status: 403 });
  const allowed = await consumeRateLimit("admin-copyright-update", await requestFingerprint(request, actor.id), 30, 60 * 60 * 1000);
  if (!allowed) return redirectTo(request, "/messages?copyright_error=İşlem+sınırı+aşıldı.#copyright-notices");

  const { id } = await params;
  const form = await request.formData();
  const status = String(form.get("status") ?? "") as CopyrightNoticeStatus;
  const publicResponse = String(form.get("public_response") ?? "").trim();
  if (!COPYRIGHT_NOTICE_STATUSES.includes(status)) return new Response("Geçersiz durum.", { status: 400 });
  if (publicResponse.length > 1200) return redirectTo(request, "/messages?copyright_error=Başvuru+sahibine+yanıt+1200+karakteri+aşamaz.#copyright-notices");

  const db = await getDatabase();
  const current = await db.prepare("SELECT status FROM copyright_notices WHERE id = ?").bind(id).first<{ status: CopyrightNoticeStatus }>();
  if (!current) return new Response("Bildirim bulunamadı.", { status: 404 });
  const now = Date.now();
  const resolvedAt = status === "action_taken" || status === "rejected" ? now : null;
  await db.prepare("UPDATE copyright_notices SET status = ?, public_response = ?, resolved_at = ?, updated_at = ? WHERE id = ?")
    .bind(status, publicResponse || null, resolvedAt, now, id).run();
  await writeAudit(actor.id, "copyright.status_updated", { noticeId: id, previousStatus: current.status, newStatus: status });
  return redirectTo(request, "/messages?copyright_updated=1#copyright-notices");
}
