import { assertSameOrigin, getCurrentSessionHash, getCurrentUser } from "../../../../lib/auth";
import { errorRedirect, redirectTo } from "../../../../lib/auth-http";
import { getDatabase, writeAudit } from "../../../../lib/database";
import {
  ACCOUNT_JSON_HEADERS,
  AccountRuntimeError,
  accountErrorResponse,
  assertAccountMutationOrigin,
  objectInput,
  readLimitedAccountJson,
  requireAccountActor,
} from "../../../../lib/account-runtime";
import { revokeAccountSessions } from "../../../../lib/account-sessions";

export async function POST(request: Request) {
  if ((request.headers.get("content-type") ?? "").toLowerCase().startsWith("application/json")) {
    try {
      const actor = await requireAccountActor(request);
      assertAccountMutationOrigin(request, actor);
      const input = objectInput(await readLimitedAccountJson(request), ["scope"]);
      if (input.scope !== "others" && input.scope !== "all") {
        throw new AccountRuntimeError("invalid_request", "Oturum iptal kapsamı geçersiz.", 400);
      }
      return Response.json(await revokeAccountSessions(actor, input.scope), { headers: ACCOUNT_JSON_HEADERS });
    } catch (error) {
      return accountErrorResponse(error);
    }
  }
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
