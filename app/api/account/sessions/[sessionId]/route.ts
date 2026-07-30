import {
  ACCOUNT_JSON_HEADERS,
  accountErrorResponse,
  assertAccountMutationOrigin,
  requireAccountActor,
} from "../../../../lib/account-runtime";
import { revokeAccountSession } from "../../../../lib/account-sessions";

export async function DELETE(
  request: Request,
  { params }: { params: Promise<{ sessionId: string }> },
) {
  try {
    const actor = await requireAccountActor(request);
    assertAccountMutationOrigin(request, actor);
    const { sessionId } = await params;
    return Response.json(await revokeAccountSession(actor, sessionId), { headers: ACCOUNT_JSON_HEADERS });
  } catch (error) {
    return accountErrorResponse(error);
  }
}
