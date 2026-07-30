import {
  ACCOUNT_JSON_HEADERS,
  accountErrorResponse,
  requireAccountActor,
} from "../../../lib/account-runtime";
import { listBlockedAccounts } from "../../../lib/account-blocks";

export async function GET(request: Request) {
  try {
    return Response.json(await listBlockedAccounts(await requireAccountActor(request)), { headers: ACCOUNT_JSON_HEADERS });
  } catch (error) {
    return accountErrorResponse(error);
  }
}
