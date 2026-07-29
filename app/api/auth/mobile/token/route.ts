import {
  auth0ErrorResponse,
  auth0GatewayConfig,
  Auth0RuntimeError,
  exchangeMobileToken,
  parseMobileTokenRequest,
  readLimitedAuthJson,
} from "../../../../lib/auth0-runtime";
import { requestFingerprint, consumeRateLimit } from "../../../../lib/rate-limit";
import { AUTH_RESPONSE_HEADERS, productionAuthUnavailable } from "../../../../lib/production-auth";

export async function POST(request: Request) {
  const config = await auth0GatewayConfig();
  if (!config) return productionAuthUnavailable();
  try {
    const body = await readLimitedAuthJson(request, 16_384);
    const input = parseMobileTokenRequest(body, config.allowedMobileRedirectUris);
    const fingerprintValue = input.grantType === "authorization_code"
      ? input.authorizationCode
      : input.refreshToken;
    const allowed = await consumeRateLimit(
      "auth0-mobile-token",
      await requestFingerprint(request, fingerprintValue),
      20,
      15 * 60 * 1000,
    );
    if (!allowed) {
      return auth0ErrorResponse(new Auth0RuntimeError("rate_limited", "Çok fazla token isteği yapıldı.", 429, false, 60));
    }
    return Response.json(await exchangeMobileToken(input, config), { headers: AUTH_RESPONSE_HEADERS });
  } catch (error) {
    return auth0ErrorResponse(error);
  }
}
