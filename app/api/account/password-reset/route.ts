import { queuePasswordReset } from "../../../lib/account-flows";
import {
  ACCOUNT_JSON_HEADERS,
  AccountRuntimeError,
  accountErrorResponse,
  assertAccountMutationOrigin,
  objectInput,
  readLimitedAccountJson,
  requireAccountActor,
} from "../../../lib/account-runtime";
import { auth0GatewayConfig } from "../../../lib/auth0-runtime";
import {
  auth0ManagementConfig,
  requestAuth0PasswordReset,
} from "../../../lib/auth0-management";
import { consumeRateLimit, requestFingerprint } from "../../../lib/rate-limit";

export async function POST(request: Request) {
  try {
    const actor = await requireAccountActor(request);
    assertAccountMutationOrigin(request, actor);
    objectInput(await readLimitedAccountJson(request), []);
    if (actor.provider !== "database") {
      throw new AccountRuntimeError("unsupported_action", "Şifre sosyal kimlik sağlayıcısı tarafından yönetiliyor.", 409);
    }
    const allowed = await consumeRateLimit(
      "account-password-reset",
      await requestFingerprint(request, actor.user.id),
      5,
      60 * 60 * 1000,
    );
    if (!allowed) throw new AccountRuntimeError("rate_limited", "Çok fazla şifre yenileme isteği yapıldı.", 429, false, 300);

    const gateway = await auth0GatewayConfig();
    const management = gateway ? await auth0ManagementConfig(gateway) : null;
    if (actor.issuer && gateway && management) {
      await requestAuth0PasswordReset(gateway, management, actor.user.email);
    } else if (!actor.issuer) {
      await queuePasswordReset(actor.user.id, actor.user.email, new URL(request.url).origin);
    } else {
      throw new AccountRuntimeError("service_unavailable", "Şifre yenileme sağlayıcısı yapılandırılmamış.", 503, false, 300);
    }
    return Response.json({ schemaVersion: "1.0", accepted: true }, { status: 202, headers: ACCOUNT_JSON_HEADERS });
  } catch (error) {
    return accountErrorResponse(error);
  }
}
