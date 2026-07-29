import {
  auth0ErrorResponse,
  auth0GatewayConfig,
  parseRevokeRequest,
  readLimitedAuthJson,
  revokeMobileToken,
} from "../../../../lib/auth0-runtime";
import { AUTH_RESPONSE_HEADERS, productionAuthUnavailable } from "../../../../lib/production-auth";

export async function POST(request: Request) {
  const config = await auth0GatewayConfig();
  if (!config) return productionAuthUnavailable();
  try {
    const body = await readLimitedAuthJson(request, 8_192);
    const input = parseRevokeRequest(body);
    return Response.json(await revokeMobileToken(input.refreshToken, config), { headers: AUTH_RESPONSE_HEADERS });
  } catch (error) {
    return auth0ErrorResponse(error);
  }
}
