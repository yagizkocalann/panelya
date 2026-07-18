import { assertSameOrigin, getCurrentUser, getPasswordHash, verifyPassword } from "../../../lib/auth";
import { clearSessionCookie, errorRedirect, redirectTo } from "../../../lib/auth-http";
import { getDatabase } from "../../../lib/database";

export async function POST(request: Request) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, "/login");
  const form = await request.formData();
  const stored = await getPasswordHash(user.id);
  if (!stored || !(await verifyPassword(String(form.get("password") ?? ""), stored.password_hash))) return errorRedirect(request, "/account", "Hesabı silmek için şifreni doğrula.");
  const db = await getDatabase();
  await db.prepare("DELETE FROM users WHERE id = ?").bind(user.id).run();
  const response = redirectTo(request, "/?account_deleted=1");
  clearSessionCookie(response);
  return response;
}
