import {
  ACCOUNT_JSON_HEADERS,
  accountErrorResponse,
  assertAccountMutationOrigin,
  readLimitedAccountJson,
  requireAccountActor,
} from "../../../../lib/account-runtime";
import {
  completeAccountReauthentication,
  parseReauthenticationComplete,
} from "../../../../lib/account-reauthentication";

export async function POST(request: Request) {
  try {
    const actor = await requireAccountActor(request);
    assertAccountMutationOrigin(request, actor);
    const input = parseReauthenticationComplete(await readLimitedAccountJson(request));
    return Response.json(await completeAccountReauthentication(actor, input), { headers: ACCOUNT_JSON_HEADERS });
  } catch (error) {
    return accountErrorResponse(error);
  }
}
