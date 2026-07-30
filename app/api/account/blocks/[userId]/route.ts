import {
  ACCOUNT_JSON_HEADERS,
  accountErrorResponse,
  assertAccountMutationOrigin,
  requireAccountActor,
} from "../../../../lib/account-runtime";
import { blockAccount, unblockAccount } from "../../../../lib/account-blocks";

type RouteContext = { params: Promise<{ userId: string }> };

export async function PUT(request: Request, { params }: RouteContext) {
  try {
    const actor = await requireAccountActor(request);
    assertAccountMutationOrigin(request, actor);
    const { userId } = await params;
    return Response.json(await blockAccount(actor, userId), { status: 202, headers: ACCOUNT_JSON_HEADERS });
  } catch (error) {
    return accountErrorResponse(error);
  }
}

export async function DELETE(request: Request, { params }: RouteContext) {
  try {
    const actor = await requireAccountActor(request);
    assertAccountMutationOrigin(request, actor);
    const { userId } = await params;
    return Response.json(await unblockAccount(actor, userId), { headers: ACCOUNT_JSON_HEADERS });
  } catch (error) {
    return accountErrorResponse(error);
  }
}
