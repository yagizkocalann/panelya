import { queueEmailVerification } from "../../../lib/account-flows";
import { assertSameOrigin, createSession, getCurrentUser, getPasswordHash, normalizeEmail, verifyPassword } from "../../../lib/auth";
import { errorRedirect, redirectTo, setSessionCookie } from "../../../lib/auth-http";
import { getDatabase, writeAudit } from "../../../lib/database";
import { sendNotification } from "../../../lib/notifications";

export async function POST(request: Request) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, "/login?return_to=/account");
  const form = await request.formData();
  const email = normalizeEmail(String(form.get("email") ?? ""));
  const currentPassword = String(form.get("current_password") ?? "");
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 160) return errorRedirect(request, "/account", "Geçerli bir e-posta gir.");
  if (email === user.email) return redirectTo(request, "/account?notice=E-posta%20adresi%20değişmedi.");
  const stored = await getPasswordHash(user.id);
  if (!stored || !(await verifyPassword(currentPassword, stored.password_hash))) return errorRedirect(request, "/account", "E-posta değişikliği için mevcut şifreni doğrula.");
  const db = await getDatabase();
  try {
    await db.prepare("UPDATE users SET email = ?, email_verified_at = NULL, updated_at = ? WHERE id = ?").bind(email, Date.now(), user.id).run();
  } catch (error) {
    if (String(error).toLowerCase().includes("unique")) return errorRedirect(request, "/account", "Bu e-posta başka bir hesapta kullanılıyor.");
    return errorRedirect(request, "/account", "E-posta adresi güncellenemedi.");
  }
  await db.prepare("DELETE FROM sessions WHERE user_id = ?").bind(user.id).run();
  const session = await createSession(user.id, true, request.headers.get("user-agent"));
  await Promise.all([
    queueEmailVerification(user.id, email, new URL(request.url).origin),
    sendNotification({ userId: user.id, recipient: user.email, kind: "security_notice", subject: "Panelya e-posta adresin değişti", body: `Hesap e-posta adresi ${email} olarak değiştirildi.` }),
    writeAudit(user.id, "account.email_changed"),
  ]);
  const response = redirectTo(request, "/account?notice=Yeni%20e-posta%20adresini%20yerel%20kutudan%20doğrula.");
  setSessionCookie(response, request, session.rawToken, session.expiresAt);
  return response;
}
