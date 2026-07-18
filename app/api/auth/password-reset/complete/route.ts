import { consumeAccountToken } from "../../../../lib/account-tokens";
import { assertSameOrigin, hashPassword, validatePassword } from "../../../../lib/auth";
import { errorRedirect, redirectTo } from "../../../../lib/auth-http";
import { getDatabase, writeAudit } from "../../../../lib/database";

export async function POST(request: Request) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const form = await request.formData();
  const token = String(form.get("token") ?? "");
  const password = String(form.get("password") ?? "");
  const confirmation = String(form.get("password_confirmation") ?? "");
  const tokenQuery = `?token=${encodeURIComponent(token)}`;
  const validationError = validatePassword(password);
  if (validationError) return errorRedirect(request, `/reset-password${tokenQuery}`, validationError);
  if (password !== confirmation) return errorRedirect(request, `/reset-password${tokenQuery}`, "Şifreler eşleşmiyor.");
  const passwordHash = await hashPassword(password);
  const accountToken = await consumeAccountToken(token, "password_reset");
  if (!accountToken) return errorRedirect(request, "/reset-password", "Bağlantı geçersiz, kullanılmış veya süresi dolmuş.");
  const db = await getDatabase();
  await db.batch([
    db.prepare("UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?").bind(passwordHash, Date.now(), accountToken.user_id),
    db.prepare("DELETE FROM sessions WHERE user_id = ?").bind(accountToken.user_id),
  ]);
  await writeAudit(accountToken.user_id, "account.password_reset");
  return redirectTo(request, "/login?notice=Şifren%20yenilendi.%20Yeni%20şifrenle%20giriş%20yap.");
}
