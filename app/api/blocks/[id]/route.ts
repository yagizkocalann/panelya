import { assertSameOrigin, getCurrentUser, safeReturnTo } from "../../../lib/auth";
import { redirectTo } from "../../../lib/auth-http";
import { getDatabase, writeAudit } from "../../../lib/database";
import { consumeRateLimit, requestFingerprint } from "../../../lib/rate-limit";

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, "/login");
  if (!user.emailVerifiedAt) return redirectTo(request, "/account?error=Engelleme%20için%20e-posta%20adresini%20doğrula.");
  const { id: targetUserId } = await params;
  const form = await request.formData();
  const returnTo = safeReturnTo(form.get("return_to"), "/account");
  if (targetUserId === user.id) return new Response("Kendini engelleyemezsin.", { status: 400 });
  const allowed = await consumeRateLimit("user-block", await requestFingerprint(request, user.id), 30, 60 * 60 * 1000);
  if (!allowed) return redirectTo(request, "/account?error=Engelleme%20sınırına%20ulaşıldı.%20Biraz%20sonra%20yeniden%20dene.");
  const db = await getDatabase();
  const target = await db.prepare("SELECT id FROM users WHERE id = ?").bind(targetUserId).first<{ id: string }>();
  if (!target) return new Response("Kullanıcı bulunamadı.", { status: 404 });
  if (form.get("action") === "unblock") {
    await db.prepare("DELETE FROM user_blocks WHERE blocker_user_id = ? AND blocked_user_id = ?").bind(user.id, targetUserId).run();
    await writeAudit(user.id, "account.user_unblocked", { targetUserId });
    return redirectTo(request, returnTo.includes("?") ? `${returnTo}&unblocked=1` : `${returnTo}?unblocked=1`);
  }
  await db.prepare("INSERT OR IGNORE INTO user_blocks (blocker_user_id, blocked_user_id, created_at) VALUES (?, ?, ?)")
    .bind(user.id, targetUserId, Date.now()).run();
  await writeAudit(user.id, "account.user_blocked", { targetUserId });
  const separator = returnTo.includes("?") ? "&" : "?";
  return redirectTo(request, `${returnTo}${separator}community=user-blocked#community`);
}
