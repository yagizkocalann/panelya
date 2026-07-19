import { assertSameOrigin, getCurrentUser, hasRecentAuthentication } from "../../../../../lib/auth";
import { reauthenticationRedirect } from "../../../../../lib/auth-http";
import { getDatabase, writeAudit } from "../../../../../lib/database";
import { isStudioRequest } from "../../../../../lib/site-origins";

function redirectWith(request: Request, key: "error" | "updated", value: string) {
  const url = new URL("/users", request.url);
  url.searchParams.set(key, value);
  return Response.redirect(url, 303);
}

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  if (!isStudioRequest(request)) return new Response("Not found", { status: 404 });
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const actor = await getCurrentUser();
  if (!actor) return Response.redirect(new URL("/login?return_to=/users", request.url), 303);
  if (actor.role !== "admin") return new Response("Yetkisiz.", { status: 403 });
  if (!(await hasRecentAuthentication())) return reauthenticationRedirect(request, "/users");

  const { id: targetUserId } = await params;
  if (targetUserId === actor.id) return redirectWith(request, "error", "Kendi rolünü bu ekrandan değiştiremezsin.");
  const form = await request.formData();
  const newRole = form.get("role") === "admin" ? "admin" : form.get("role") === "reader" ? "reader" : null;
  if (!newRole) return redirectWith(request, "error", "Geçerli bir rol seç.");

  const db = await getDatabase();
  const target = await db.prepare("SELECT id, role FROM users WHERE id = ?").bind(targetUserId).first<{ id: string; role: "reader" | "admin" }>();
  if (!target) return redirectWith(request, "error", "Kullanıcı bulunamadı.");
  if (target.role === newRole) return redirectWith(request, "updated", targetUserId);
  if (target.role === "admin" && newRole === "reader") {
    const admins = await db.prepare("SELECT COUNT(*) AS count FROM users WHERE role = 'admin'").first<{ count: number }>();
    if (Number(admins?.count ?? 0) <= 1) return redirectWith(request, "error", "Son yönetici okuyucuya dönüştürülemez.");
  }

  const now = Date.now();
  const updated = await db.prepare(`UPDATE users SET role = ?, updated_at = ?
    WHERE id = ? AND role = ?
      AND NOT (role = 'admin' AND ? = 'reader' AND (SELECT COUNT(*) FROM users WHERE role = 'admin') <= 1)`)
    .bind(newRole, now, targetUserId, target.role, newRole).run();
  if (Number(updated.meta.changes ?? 0) !== 1) return redirectWith(request, "error", "Rol değişikliği güvenlik kontrolünden geçmedi; listeyi yenileyip tekrar dene.");
  await db.prepare("DELETE FROM sessions WHERE user_id = ?").bind(targetUserId).run();
  await writeAudit(actor.id, "admin.user_role_changed", { targetUserId, previousRole: target.role, newRole });
  return redirectWith(request, "updated", targetUserId);
}
