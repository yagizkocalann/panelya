import { auth0GatewayConfig, publicAuth0Config } from "../../../lib/auth0-runtime";
import { AUTH_RESPONSE_HEADERS, productionAuthUnavailable } from "../../../lib/production-auth";

export async function GET() {
  const config = await auth0GatewayConfig();
  return config
    ? Response.json(publicAuth0Config(config), { headers: AUTH_RESPONSE_HEADERS })
    : productionAuthUnavailable();
}
