import { AUTH_RESPONSE_HEADERS, productionAuthConfig, productionAuthUnavailable } from "../../../lib/production-auth";

export async function GET() {
  const config = await productionAuthConfig();
  return config
    ? Response.json(config, { headers: AUTH_RESPONSE_HEADERS })
    : productionAuthUnavailable();
}
