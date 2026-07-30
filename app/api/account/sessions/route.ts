import {
  ACCOUNT_JSON_HEADERS,
  accountErrorResponse,
  requireAccountActor,
} from "../../../lib/account-runtime";
import { listAccountSessions } from "../../../lib/account-sessions";

export async function GET(request: Request) {
  try {
    return Response.json(await listAccountSessions(await requireAccountActor(request)), { headers: ACCOUNT_JSON_HEADERS });
  } catch (error) {
    return accountErrorResponse(error);
  }
}
