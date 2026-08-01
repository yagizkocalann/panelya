import {
  ACCOUNT_JSON_HEADERS,
  AccountRuntimeError,
  accountCapabilities,
  accountErrorResponse,
  assertAccountMutationOrigin,
  normalizeAccountEmail,
  objectInput,
  readLimitedAccountJson,
  requireAccountActor,
} from "../../../lib/account-runtime";
import { consumeReauthenticationToken } from "../../../lib/account-reauthentication";
import { auth0GatewayConfig } from "../../../lib/auth0-runtime";
import { auth0ManagementConfig, updateAuth0Email } from "../../../lib/auth0-management";
import { writeAudit } from "../../../lib/database";
import { consumeRateLimit, requestFingerprint } from "../../../lib/rate-limit";

export async function POST(request: Request) {
  try {
    const actor = await requireAccountActor(request);
    assertAccountMutationOrigin(request, actor);
    if (accountCapabilities(actor.provider).emailChange === "unavailable") {
      throw new AccountRuntimeError("unsupported_action", "E-posta değiştirme şu anda kullanıma açık değil.", 409);
    }
    const input = objectInput(await readLimitedAccountJson(request), ["newEmail", "reauthenticationToken"]);
    const newEmail = normalizeAccountEmail(input.newEmail);
    if (typeof input.reauthenticationToken !== "string") {
      throw new AccountRuntimeError("invalid_request", "Yeniden doğrulama kanıtı eksik.", 400);
    }
    if (newEmail === actor.user.email) {
      throw new AccountRuntimeError("conflict", "Yeni e-posta mevcut adresle aynı.", 409);
    }
    const allowed = await consumeRateLimit(
      "account-email-change",
      await requestFingerprint(request, actor.user.id),
      5,
      60 * 60 * 1000,
    );
    if (!allowed) throw new AccountRuntimeError("rate_limited", "Çok fazla e-posta değişikliği istendi.", 429, false, 300);
    const gateway = await auth0GatewayConfig();
    const management = gateway ? await auth0ManagementConfig(gateway) : null;
    if (!gateway || !management) {
      throw new AccountRuntimeError("service_unavailable", "Kimlik yönetim sağlayıcısı yapılandırılmamış.", 503, false, 300);
    }
    const provider = await consumeReauthenticationToken(
      actor,
      "email_change",
      input.reauthenticationToken,
    );
    if (provider.issuer !== gateway.issuer) {
      throw new AccountRuntimeError("reauthentication_invalid", "Yeniden doğrulama kanıtı geçersiz.", 401, true);
    }
    await updateAuth0Email(management, provider.subject, newEmail);
    await writeAudit(actor.user.id, "account.email_change_requested", { transport: actor.transport });
    return Response.json({ schemaVersion: "1.0", accepted: true }, { status: 202, headers: ACCOUNT_JSON_HEADERS });
  } catch (error) {
    return accountErrorResponse(error);
  }
}
