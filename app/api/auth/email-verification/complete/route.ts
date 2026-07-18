import { consumeAccountToken } from "../../../../lib/account-tokens";
import { assertSameOrigin } from "../../../../lib/auth";
import { errorRedirect, redirectTo } from "../../../../lib/auth-http";
import { getDatabase, writeAudit } from "../../../../lib/database";

export async function POST(request: Request) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const form = await request.formData();
  const token = String(form.get("token") ?? "");
  const accountToken = await consumeAccountToken(token, "verify_email");
  if (!accountToken) return errorRedirect(request, "/verify-email", "Bağlantı geçersiz, kullanılmış veya süresi dolmuş.");
  const db = await getDatabase();
  const result = await db.prepare(`UPDATE users SET email_verified_at = ?, updated_at = ?
    WHERE id = ? AND email = ?`).bind(Date.now(), Date.now(), accountToken.user_id, accountToken.target_email).run();
  if (!result.meta.changes) return errorRedirect(request, "/verify-email", "Bu bağlantı artık güncel e-posta adresine ait değil.");
  await writeAudit(accountToken.user_id, "account.email_verified");
  return redirectTo(request, "/account?verified=1");
}
