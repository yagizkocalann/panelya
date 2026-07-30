import {
  ACCOUNT_JSON_HEADERS,
  AccountRuntimeError,
  accountErrorResponse,
  assertAccountMutationOrigin,
  objectInput,
  readLimitedAccountJson,
  requireAccountActor,
} from "../../../lib/account-runtime";
import { accountDeletionSummary, deleteAccount } from "../../../lib/account-deletion";
import { consumeRateLimit, requestFingerprint } from "../../../lib/rate-limit";

export async function GET(request: Request) {
  try {
    await requireAccountActor(request);
    return Response.json(accountDeletionSummary(), { headers: ACCOUNT_JSON_HEADERS });
  } catch (error) {
    return accountErrorResponse(error);
  }
}

export async function POST(request: Request) {
  try {
    const actor = await requireAccountActor(request);
    assertAccountMutationOrigin(request, actor);
    const input = objectInput(await readLimitedAccountJson(request), ["confirmation", "reauthenticationToken"]);
    const idempotencyKey = request.headers.get("idempotency-key") ?? "";
    if (idempotencyKey.length < 16 || idempotencyKey.length > 128 || /[\u0000-\u001f\u007f]/.test(idempotencyKey)) {
      throw new AccountRuntimeError("invalid_request", "Idempotency-Key başlığı geçersiz.", 400);
    }
    const allowed = await consumeRateLimit(
      "account-deletion",
      await requestFingerprint(request, actor.user.id),
      3,
      24 * 60 * 60 * 1000,
    );
    if (!allowed) throw new AccountRuntimeError("rate_limited", "Çok fazla hesap silme isteği yapıldı.", 429, false, 3600);
    return Response.json(
      await deleteAccount(actor, input.confirmation, input.reauthenticationToken, idempotencyKey),
      { status: 202, headers: ACCOUNT_JSON_HEADERS },
    );
  } catch (error) {
    return accountErrorResponse(error);
  }
}
