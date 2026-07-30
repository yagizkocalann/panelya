import {
  ACCOUNT_JSON_HEADERS,
  AccountRuntimeError,
  accountErrorResponse,
  assertAccountMutationOrigin,
  readLimitedAccountJson,
  requireAccountActor,
} from "../../../../lib/account-runtime";
import {
  parseReauthenticationStart,
  startAccountReauthentication,
} from "../../../../lib/account-reauthentication";
import { consumeRateLimit, requestFingerprint } from "../../../../lib/rate-limit";

export async function POST(request: Request) {
  try {
    const actor = await requireAccountActor(request);
    assertAccountMutationOrigin(request, actor);
    const allowed = await consumeRateLimit(
      "account-reauth-start",
      await requestFingerprint(request, actor.user.id),
      10,
      15 * 60 * 1000,
    );
    if (!allowed) throw new AccountRuntimeError("rate_limited", "Çok fazla yeniden doğrulama isteği yapıldı.", 429, false, 60);
    const input = parseReauthenticationStart(await readLimitedAccountJson(request));
    return Response.json(await startAccountReauthentication(actor, input), { headers: ACCOUNT_JSON_HEADERS });
  } catch (error) {
    return accountErrorResponse(error);
  }
}
