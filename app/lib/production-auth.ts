import { runtimeValue } from "./runtime-config";

export const AUTH_RESPONSE_HEADERS = {
  "Cache-Control": "private, no-store",
  "Referrer-Policy": "no-referrer",
} as const;

export const AUTH_SCOPES = [
  "openid",
  "profile",
  "email",
  "offline_access",
  "read:library",
  "write:library",
  "write:progress",
  "write:community",
] as const;

export function productionAuthUnavailable() {
  return Response.json(
    {
      schemaVersion: "1.0",
      error: "service_unavailable",
      errorDescription: "Production kimlik saglayicisi henuz etkin degil.",
      reauthenticate: false,
      retryAfterSeconds: 300,
    },
    { status: 503, headers: { ...AUTH_RESPONSE_HEADERS, "Retry-After": "300" } },
  );
}

function safeIssuer(value: string) {
  try {
    const url = new URL(value);
    if (url.protocol !== "https:" || url.username || url.password || url.search || url.hash) return null;
    url.pathname = `${url.pathname.replace(/\/+$/, "")}/`;
    return url.toString();
  } catch {
    return null;
  }
}

export async function productionAuthConfig() {
  const [enabled, issuerValue, clientId, audience] = await Promise.all([
    runtimeValue("AUTH0_GATEWAY_ENABLED"),
    runtimeValue("AUTH0_ISSUER"),
    runtimeValue("AUTH0_MOBILE_CLIENT_ID"),
    runtimeValue("AUTH0_AUDIENCE"),
  ]);
  const issuer = safeIssuer(issuerValue.trim());
  if (enabled.trim().toLowerCase() !== "true" || !issuer || !clientId.trim() || !audience.trim()) return null;
  return {
    schemaVersion: "1.0" as const,
    provider: "auth0" as const,
    flow: "authorization_code_pkce" as const,
    issuer,
    clientId: clientId.trim(),
    audience: audience.trim(),
    scopes: [...AUTH_SCOPES],
    authorizationEndpoint: new URL("authorize", issuer).toString(),
    tokenEndpoint: new URL("oauth/token", issuer).toString(),
    revocationEndpoint: new URL("oauth/revoke", issuer).toString(),
    accessTokenLifetimeSeconds: 900,
    refreshTokenRotation: true as const,
  };
}
