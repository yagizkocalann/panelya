import { assertSameOrigin, createSession, getCurrentUser, getPasswordHash, hashPassword, verifyPassword } from "../../../lib/auth";
import { errorRedirect, redirectTo, setSessionCookie } from "../../../lib/auth-http";
import { getDatabase, writeAudit } from "../../../lib/database";

export async function POST(request: Request) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, "/login?return_to=/account");
  const form = await request.formData();
  const currentPassword = String(form.get("current_password") ?? "");
  const password = String(form.get("password") ?? "");
  const confirmation = String(form.get("password_confirmation") ?? "");
  const stored = await getPasswordHash(user.id);
  if (!stored || !(await verifyPassword(currentPassword, stored.password_hash))) return errorRedirect(request, "/account", "Mevcut şifre yanlış.");
  if (password.length < 10 || !/[a-zA-ZçğıöşüÇĞİÖŞÜ]/.test(password) || !/[0-9]/.test(password)) return errorRedirect(request, "/account", "Yeni şifre en az 10 karakter, bir harf ve bir rakam içermeli.");
  if (password !== confirmation) return errorRedirect(request, "/account", "Yeni şifreler eşleşmiyor.");
  const db = await getDatabase();
  await db.prepare("UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?").bind(await hashPassword(password), Date.now(), user.id).run();
  await db.prepare("DELETE FROM sessions WHERE user_id = ?").bind(user.id).run();
  const session = await createSession(user.id, true, request);
  await writeAudit(user.id, "account.password_changed");
  const response = redirectTo(request, "/account?saved=password");
  setSessionCookie(response, request, session.rawToken, session.expiresAt);
  return response;
}
