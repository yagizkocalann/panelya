import { hashOpaqueToken } from "./auth";
import { AccountRuntimeError } from "./account-runtime";
import { type Auth0GatewayConfig } from "./auth0-runtime";
import { runtimeValue } from "./runtime-config";

type ManagementConfig = {
  issuer: string;
  clientId: string;
  clientSecret: string;
  audience: string;
  databaseConnection: string;
  mobileClientId: string;
};

type ManagementToken = {
  value: string;
  expiresAt: number;
};

export type Auth0DeviceCredential = {
  id: string;
  device_name?: string;
  type?: string;
  created_at?: string;
  last_used_at?: string;
};

const tokenCache = new Map<string, ManagementToken>();

function managementError(status: number) {
  if (status === 404) return new AccountRuntimeError("not_found", "Kimlik sağlayıcısında hesap bulunamadı.", 404, true);
  if (status === 400 || status === 409) {
    return new AccountRuntimeError("conflict", "Kimlik değişikliği başka bir kayıtla çakışıyor.", 409);
  }
  if (status === 429) return new AccountRuntimeError("rate_limited", "Kimlik sağlayıcısı istek sınırına ulaşıldı.", 429, false, 60);
  return new AccountRuntimeError("service_unavailable", "Kimlik sağlayıcısı yönetim isteğini tamamlayamadı.", 503, false, 60);
}

async function readJson(response: Response) {
  try {
    return await response.json();
  } catch {
    return null;
  }
}

export async function auth0ManagementConfig(gateway: Auth0GatewayConfig): Promise<ManagementConfig | null> {
  const [clientId, clientSecret, audienceValue, databaseConnection] = await Promise.all([
    runtimeValue("AUTH0_MANAGEMENT_CLIENT_ID"),
    runtimeValue("AUTH0_MANAGEMENT_CLIENT_SECRET"),
    runtimeValue("AUTH0_MANAGEMENT_AUDIENCE"),
    runtimeValue("AUTH0_DATABASE_CONNECTION"),
  ]);
  const audience = audienceValue.trim() || new URL("api/v2/", gateway.issuer).toString();
  if (!clientId.trim() || !clientSecret.trim()) return null;
  try {
    const audienceUrl = new URL(audience);
    if (audienceUrl.protocol !== "https:") return null;
  } catch {
    return null;
  }
  return {
    issuer: gateway.issuer,
    clientId: clientId.trim(),
    clientSecret: clientSecret.trim(),
    audience,
    databaseConnection: databaseConnection.trim(),
    mobileClientId: gateway.clientId,
  };
}

async function managementAccessToken(config: ManagementConfig) {
  const cacheKey = `${config.issuer}\n${config.clientId}\n${config.audience}`;
  const cached = tokenCache.get(cacheKey);
  if (cached && cached.expiresAt > Date.now() + 60_000) return cached.value;
  let response: Response;
  try {
    response = await fetch(new URL("oauth/token", config.issuer), {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({
        grant_type: "client_credentials",
        client_id: config.clientId,
        client_secret: config.clientSecret,
        audience: config.audience,
      }),
    });
  } catch {
    throw managementError(503);
  }
  const value = await readJson(response);
  if (!response.ok) throw managementError(response.status);
  const body = value && typeof value === "object" ? value as Record<string, unknown> : {};
  if (body.token_type !== "Bearer"
    || typeof body.access_token !== "string"
    || !Number.isInteger(body.expires_in)
    || Number(body.expires_in) < 60) {
    throw managementError(503);
  }
  const token = { value: body.access_token, expiresAt: Date.now() + Number(body.expires_in) * 1000 };
  tokenCache.set(cacheKey, token);
  return token.value;
}

async function managementFetch(
  config: ManagementConfig,
  path: string,
  init: RequestInit = {},
) {
  let response: Response;
  try {
    response = await fetch(new URL(path, config.issuer), {
      ...init,
      headers: {
        Authorization: `Bearer ${await managementAccessToken(config)}`,
        Accept: "application/json",
        ...init.headers,
      },
    });
  } catch {
    throw managementError(503);
  }
  if (!response.ok) throw managementError(response.status);
  return response;
}

export async function requestAuth0PasswordReset(
  gateway: Auth0GatewayConfig,
  config: ManagementConfig,
  email: string,
) {
  if (!config.databaseConnection) {
    throw new AccountRuntimeError("service_unavailable", "Auth0 database bağlantısı yapılandırılmamış.", 503, false, 300);
  }
  let response: Response;
  try {
    response = await fetch(new URL("dbconnections/change_password", gateway.issuer), {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "text/plain" },
      body: JSON.stringify({
        client_id: gateway.clientId,
        email,
        connection: config.databaseConnection,
      }),
    });
  } catch {
    throw managementError(503);
  }
  if (!response.ok) throw managementError(response.status);
}

export async function updateAuth0Email(
  config: ManagementConfig,
  subject: string,
  email: string,
) {
  await managementFetch(config, `api/v2/users/${encodeURIComponent(subject)}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, verify_email: true }),
  });
}

export async function deleteAuth0User(config: ManagementConfig, subject: string) {
  try {
    await managementFetch(config, `api/v2/users/${encodeURIComponent(subject)}`, { method: "DELETE" });
  } catch (error) {
    if (error instanceof AccountRuntimeError && error.status === 404) return;
    throw error;
  }
}

export async function listAuth0DeviceCredentials(config: ManagementConfig, subject: string) {
  const values = await Promise.all(["refresh_token", "rotating_refresh_token"].map(async (type) => {
    const url = new URL("api/v2/device-credentials", config.issuer);
    url.searchParams.set("user_id", subject);
    url.searchParams.set("client_id", config.mobileClientId);
    url.searchParams.set("type", type);
    const value = await readJson(await managementFetch(config, url.pathname + url.search));
    if (!Array.isArray(value)) throw managementError(503);
    return value.filter((item): item is Auth0DeviceCredential => Boolean(
      item && typeof item === "object" && typeof (item as Record<string, unknown>).id === "string",
    ));
  }));
  return [...new Map(values.flat().map((credential) => [credential.id, credential])).values()];
}

export async function deleteAuth0DeviceCredential(config: ManagementConfig, credentialId: string) {
  try {
    await managementFetch(config, `api/v2/device-credentials/${encodeURIComponent(credentialId)}`, { method: "DELETE" });
  } catch (error) {
    if (error instanceof AccountRuntimeError && error.status === 404) return;
    throw error;
  }
}

export async function findAuth0SubjectByEmail(
  config: ManagementConfig,
  email: string,
  issuer: string,
  expectedSubjectHash: string,
) {
  const url = new URL("api/v2/users-by-email", config.issuer);
  url.searchParams.set("email", email);
  const value = await readJson(await managementFetch(config, url.pathname + url.search));
  if (!Array.isArray(value)) throw managementError(503);
  for (const candidate of value) {
    if (!candidate || typeof candidate !== "object") continue;
    const subject = (candidate as Record<string, unknown>).user_id;
    if (typeof subject === "string"
      && await hashOpaqueToken(`${issuer}\n${subject}`) === expectedSubjectHash) {
      return subject;
    }
  }
  throw managementError(404);
}

export type { ManagementConfig as Auth0ManagementConfig };
