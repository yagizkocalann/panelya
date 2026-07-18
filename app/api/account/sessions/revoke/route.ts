import { assertSameOrigin, getCurrentSessionHash, getCurrentUser } from "../../../../lib/auth";
import { errorRedirect, redirectTo } from "../../../../lib/auth-http";
import { getDatabase, writeAudit } from "../../../../lib/database";

export async function POST(request: Request) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, "/login?return_to=/account/sessions");
  const form = await request.formData();
  const tokenHash = String(form.get("token_hash") ?? "");
  if (!tokenHash || tokenHash === await getCurrentSessionHash()) return errorRedirect(request, "/account/sessions", "Kullandığın oturumu buradan kapatamazsın; hesap ekranındaki çıkışı kullan.");
  const db = await getDatabase();
  await db.prepare("DELETE FROM sessions WHERE token_hash = ? AND user_id = ?").bind(tokenHash, user.id).run();
  await writeAudit(user.id, "account.session_revoked");
  return redirectTo(request, "/account/sessions?notice=Oturum%20kapatıldı.");
}
