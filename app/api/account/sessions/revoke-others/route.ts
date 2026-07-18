import { assertSameOrigin, getCurrentSessionHash, getCurrentUser } from "../../../../lib/auth";
import { redirectTo } from "../../../../lib/auth-http";
import { getDatabase, writeAudit } from "../../../../lib/database";

export async function POST(request: Request) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, "/login?return_to=/account/sessions");
  const currentHash = await getCurrentSessionHash();
  const db = await getDatabase();
  if (currentHash) await db.prepare("DELETE FROM sessions WHERE user_id = ? AND token_hash <> ?").bind(user.id, currentHash).run();
  await writeAudit(user.id, "account.other_sessions_revoked");
  return redirectTo(request, "/account/sessions?notice=Diğer%20oturumlar%20kapatıldı.");
}
