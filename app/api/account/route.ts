import {
  ACCOUNT_JSON_HEADERS,
  accountErrorResponse,
  accountOverview,
  requireAccountActor,
} from "../../lib/account-runtime";

export async function GET(request: Request) {
  try {
    return Response.json(accountOverview(await requireAccountActor(request)), { headers: ACCOUNT_JSON_HEADERS });
  } catch (error) {
    return accountErrorResponse(error);
  }
}
