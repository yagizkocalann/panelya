import { createRemoteJWKSet, errors as joseErrors, jwtVerify } from "jose";
import { hashOpaqueToken, normalizeEmail, type LocalUser } from "./auth";
import { getDatabase, writeAudit } from "./database";
import { productionAuthConfig } from "./production-auth";
import { runtimeValue } from "./runtime-config";

type Auth0ErrorCode =
  | "invalid_grant"
  | "login_required"
  | "token_expired"
  | "token_reused"
  | "insufficient_scope"
  | "session_revoked"
  | "rate_limited"
  | "service_unavailable";

export type Auth0GatewayConfig = NonNullable<Awaited<ReturnType<typeof productionAuthConfig>>> & {
  allowedMobileRedirectUris: ReadonlySet<string>;
  jwksUri: string;
  userInfoEndpoint: string;
};

type AuthorizationCodeRequest = {
  grantType: "authorization_code";
  authorizationCode: string;
  codeVerifier: string;
  redirectUri: string;
};

type RefreshTokenRequest = {
  grantType: "refresh_token";
  refreshToken: string;
};

export type MobileTokenRequest = AuthorizationCodeRequest | RefreshTokenRequest;

type Auth0TokenPayload = {
  access_token?: unknown;
  refresh_token?: unknown;
  token_type?: unknown;
  expires_in?: unknown;
  scope?: unknown;
};

type Auth0UserInfo = {
  sub?: unknown;
  email?: unknown;
  email_verified?: unknown;
  name?: unknown;
  nickname?: unknown;
  picture?: unknown;
};

type ProviderUserRow = {
  id: string;
  email: string;
  display_name: string;
  role: "reader" | "admin";
  email_verified_at: number | null;
  created_at: number;
  provider_kind: AccountProviderKind;
  status: "active" | "deletion_pending" | "deleted";
  sessions_valid_after: number;
};

export type AccountProviderKind = "database" | "google" | "other_social";

const CODE_VERIFIER_PATTERN = /^[A-Za-z0-9\-._~]{43,128}$/;
const EXTERNAL_PASSWORD_MARKER = "external-auth0$disabled";
const jwksByIssuer = new Map<string, ReturnType<typeof createRemoteJWKSet>>();

export class Auth0RuntimeError extends Error {
  constructor(
    public readonly code: Auth0ErrorCode,
    message: string,
    public readonly status: number,
    public readonly reauthenticate: boolean,
    public readonly retryAfterSeconds?: number,
  ) {
    super(message);
    this.name = "Auth0RuntimeError";
  }
}

function exactKeys(value: Record<string, unknown>, expected: readonly string[]) {
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  return actual.length === wanted.length && actual.every((key, index) => key === wanted[index]);
}

function normalizedRedirectUri(value: string) {
  try {
    const url = new URL(value);
    if (!url.protocol || url.username || url.password || url.search || url.hash) return null;
    return url.toString();
  } catch {
    return null;
  }
}

export function parseAllowedMobileRedirectUris(value: string) {
  const redirects = new Set<string>();
  for (const candidate of value.split(",")) {
    const redirect = normalizedRedirectUri(candidate.trim());
    if (redirect) redirects.add(redirect);
  }
  return redirects;
}

export async function readLimitedAuthJson(request: Request, maximumBytes: number) {
  if (!(request.headers.get("content-type") ?? "").toLowerCase().startsWith("application/json")) {
    throw new Auth0RuntimeError("invalid_grant", "Kimlik isteği JSON olmalı.", 400, true);
  }
  const declaredLength = Number(request.headers.get("content-length") ?? 0);
  if (Number.isFinite(declaredLength) && declaredLength > maximumBytes) {
    throw new Auth0RuntimeError("invalid_grant", "Kimlik isteği çok büyük.", 400, true);
  }
  if (!request.body) {
    throw new Auth0RuntimeError("invalid_grant", "Kimlik isteği gövdesi eksik.", 400, true);
  }
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    totalBytes += value.byteLength;
    if (totalBytes > maximumBytes) {
      await reader.cancel();
      throw new Auth0RuntimeError("invalid_grant", "Kimlik isteği çok büyük.", 400, true);
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes)) as unknown;
  } catch {
    throw new Auth0RuntimeError("invalid_grant", "Geçerli bir JSON gövdesi gönderilmeli.", 400, true);
  }
}

export function parseMobileTokenRequest(
  value: unknown,
  allowedRedirectUris: ReadonlySet<string>,
): MobileTokenRequest {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Auth0RuntimeError("invalid_grant", "Geçersiz token isteği.", 400, true);
  }
  const input = value as Record<string, unknown>;
  if (input.grantType === "authorization_code") {
    if (!exactKeys(input, ["grantType", "authorizationCode", "codeVerifier", "redirectUri"])
      || typeof input.authorizationCode !== "string"
      || input.authorizationCode.length < 16
      || typeof input.codeVerifier !== "string"
      || !CODE_VERIFIER_PATTERN.test(input.codeVerifier)
      || typeof input.redirectUri !== "string") {
      throw new Auth0RuntimeError("invalid_grant", "Geçersiz yetkilendirme kodu isteği.", 400, true);
    }
    const redirectUri = normalizedRedirectUri(input.redirectUri);
    if (!redirectUri || !allowedRedirectUris.has(redirectUri)) {
      throw new Auth0RuntimeError("invalid_grant", "Geri dönüş adresine izin verilmiyor.", 400, true);
    }
    return {
      grantType: "authorization_code",
      authorizationCode: input.authorizationCode,
      codeVerifier: input.codeVerifier,
      redirectUri,
    };
  }
  if (input.grantType === "refresh_token") {
    if (!exactKeys(input, ["grantType", "refreshToken"])
      || typeof input.refreshToken !== "string"
      || input.refreshToken.length < 16) {
      throw new Auth0RuntimeError("invalid_grant", "Geçersiz yenileme isteği.", 400, true);
    }
    return { grantType: "refresh_token", refreshToken: input.refreshToken };
  }
  throw new Auth0RuntimeError("invalid_grant", "Desteklenmeyen token isteği.", 400, true);
}

export function parseRevokeRequest(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Auth0RuntimeError("invalid_grant", "Geçersiz oturum kapatma isteği.", 400, true);
  }
  const input = value as Record<string, unknown>;
  if (!exactKeys(input, ["refreshToken"])
    || typeof input.refreshToken !== "string"
    || input.refreshToken.length < 16) {
    throw new Auth0RuntimeError("invalid_grant", "Geçersiz yenileme tokeni.", 400, true);
  }
  return { refreshToken: input.refreshToken };
}

export async function auth0GatewayConfig(): Promise<Auth0GatewayConfig | null> {
  const [config, redirectsValue] = await Promise.all([
    productionAuthConfig(),
    runtimeValue("AUTH0_MOBILE_REDIRECT_URIS"),
  ]);
  if (!config) return null;
  const allowedMobileRedirectUris = parseAllowedMobileRedirectUris(redirectsValue);
  if (allowedMobileRedirectUris.size === 0) return null;
  return {
    ...config,
    allowedMobileRedirectUris,
    jwksUri: new URL(".well-known/jwks.json", config.issuer).toString(),
    userInfoEndpoint: new URL("userinfo", config.issuer).toString(),
  };
}

export function publicAuth0Config(config: Auth0GatewayConfig) {
  return {
    schemaVersion: config.schemaVersion,
    provider: config.provider,
    flow: config.flow,
    issuer: config.issuer,
    clientId: config.clientId,
    audience: config.audience,
    scopes: config.scopes,
    authorizationEndpoint: config.authorizationEndpoint,
    tokenEndpoint: config.tokenEndpoint,
    revocationEndpoint: config.revocationEndpoint,
    accessTokenLifetimeSeconds: config.accessTokenLifetimeSeconds,
    refreshTokenRotation: config.refreshTokenRotation,
  };
}

function auth0ProviderError(status: number, value: unknown) {
  const body = value && typeof value === "object" ? value as Record<string, unknown> : {};
  const providerCode = typeof body.error === "string" ? body.error : "";
  const providerDescription = typeof body.error_description === "string" ? body.error_description.toLowerCase() : "";
  if (status === 429) {
    return new Auth0RuntimeError("rate_limited", "Çok fazla kimlik isteği yapıldı.", 429, false, 60);
  }
  if (providerCode === "invalid_grant") {
    if (providerDescription.includes("reuse") || providerDescription.includes("reused")) {
      return new Auth0RuntimeError("token_reused", "Yenileme tokeni yeniden kullanıldı.", 400, true);
    }
    return new Auth0RuntimeError("invalid_grant", "Kimlik doğrulama isteği geçersiz veya süresi dolmuş.", 400, true);
  }
  if (providerCode === "login_required" || providerCode === "access_denied") {
    return new Auth0RuntimeError("login_required", "Yeniden giriş yapılması gerekiyor.", 401, true);
  }
  return new Auth0RuntimeError("service_unavailable", "Kimlik sağlayıcısı isteği tamamlanamadı.", 503, false, 60);
}

async function readProviderJson(response: Response) {
  try {
    return await response.json();
  } catch {
    return null;
  }
}

function jwksFor(config: Auth0GatewayConfig) {
  const cached = jwksByIssuer.get(config.issuer);
  if (cached) return cached;
  const jwks = createRemoteJWKSet(new URL(config.jwksUri), {
    cooldownDuration: 30_000,
    timeoutDuration: 5_000,
  });
  jwksByIssuer.set(config.issuer, jwks);
  return jwks;
}

export async function validateAuth0AccessToken(
  accessToken: string,
  config: Auth0GatewayConfig,
  requiredScopes: readonly string[] = [],
) {
  try {
    const verified = await jwtVerify(accessToken, jwksFor(config), {
      issuer: config.issuer,
      audience: config.audience,
      algorithms: ["RS256"],
      clockTolerance: 5,
    });
    if (typeof verified.payload.sub !== "string" || !verified.payload.sub) {
      throw new Auth0RuntimeError("invalid_grant", "Access token kullanıcı kimliği taşımıyor.", 401, true);
    }
    if (verified.payload.azp !== undefined && verified.payload.azp !== config.clientId) {
      throw new Auth0RuntimeError("invalid_grant", "Access token farklı bir istemciye ait.", 401, true);
    }
    const scopes = typeof verified.payload.scope === "string"
      ? new Set(verified.payload.scope.split(/\s+/).filter(Boolean))
      : new Set<string>();
    if (requiredScopes.some((scope) => !scopes.has(scope))) {
      throw new Auth0RuntimeError("insufficient_scope", "Bu işlem için gerekli izin bulunmuyor.", 403, false);
    }
    return { payload: verified.payload, scopes: [...scopes] };
  } catch (error) {
    if (error instanceof Auth0RuntimeError) throw error;
    if (error instanceof joseErrors.JWTExpired) {
      throw new Auth0RuntimeError("token_expired", "Access token süresi dolmuş.", 401, true);
    }
    throw new Auth0RuntimeError("invalid_grant", "Access token doğrulanamadı.", 401, true);
  }
}

async function fetchAuth0UserInfo(accessToken: string, expectedSubject: string, config: Auth0GatewayConfig) {
  let response: Response;
  try {
    response = await fetch(config.userInfoEndpoint, {
      headers: { Authorization: `Bearer ${accessToken}`, Accept: "application/json" },
    });
  } catch {
    throw new Auth0RuntimeError("service_unavailable", "Kullanıcı profili alınamadı.", 503, false, 60);
  }
  const value = await readProviderJson(response);
  if (!response.ok) throw auth0ProviderError(response.status, value);
  const profile = value && typeof value === "object" ? value as Auth0UserInfo : {};
  if (profile.sub !== expectedSubject
    || typeof profile.email !== "string"
    || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(profile.email)) {
    throw new Auth0RuntimeError("service_unavailable", "Kimlik sağlayıcısı geçerli kullanıcı profili döndürmedi.", 503, false, 60);
  }
  const email = normalizeEmail(profile.email);
  const displayNameCandidate = typeof profile.name === "string" && profile.name.trim()
    ? profile.name.trim()
    : typeof profile.nickname === "string" && profile.nickname.trim()
      ? profile.nickname.trim()
      : email.split("@")[0];
  const avatarUrl = typeof profile.picture === "string" && /^https:\/\//i.test(profile.picture)
    ? profile.picture
    : undefined;
  return {
    subject: expectedSubject,
    email,
    emailVerified: profile.email_verified === true,
    displayName: displayNameCandidate.slice(0, 80),
    avatarUrl,
  };
}

function providerRowToUser(row: ProviderUserRow): LocalUser {
  return {
    id: row.id,
    email: row.email,
    displayName: row.display_name,
    role: row.role,
    emailVerifiedAt: row.email_verified_at,
    createdAt: row.created_at,
  };
}

export function providerKindForSubject(subject: string): AccountProviderKind {
  const connection = subject.split("|", 1)[0]?.toLowerCase();
  if (connection === "auth0") return "database";
  if (connection === "google-oauth2") return "google";
  return "other_social";
}

async function findProviderIdentity(issuer: string, subjectHash: string) {
  const db = await getDatabase();
  const row = await db.prepare(`SELECT u.id, u.email, u.display_name, u.role, u.email_verified_at, u.created_at,
      u.status, u.sessions_valid_after, p.provider_kind
    FROM provider_identities p JOIN users u ON u.id = p.user_id
    WHERE p.provider = 'auth0' AND p.issuer = ? AND p.subject_hash = ?`)
    .bind(issuer, subjectHash)
    .first<ProviderUserRow>();
  return row ? {
    user: providerRowToUser(row),
    providerKind: row.provider_kind,
    status: row.status,
    sessionsValidAfter: row.sessions_valid_after,
  } : null;
}

async function findProviderUser(issuer: string, subjectHash: string) {
  return (await findProviderIdentity(issuer, subjectHash))?.user ?? null;
}

async function resolveProviderUser(
  profile: Awaited<ReturnType<typeof fetchAuth0UserInfo>>,
  issuer: string,
) {
  const db = await getDatabase();
  const subjectHash = await hashOpaqueToken(`${issuer}\n${profile.subject}`);
  const existingIdentity = await findProviderIdentity(issuer, subjectHash);
  const existing = existingIdentity?.user ?? null;
  const providerKind = providerKindForSubject(profile.subject);
  const now = Date.now();
  if (existing) {
    if (existingIdentity?.status !== "active") {
      throw new Auth0RuntimeError("session_revoked", "Panelya hesabı artık etkin değil.", 401, true);
    }
    await db.prepare(`UPDATE provider_identities
      SET provider_kind = ?, last_login_at = ?, updated_at = ?
      WHERE provider = 'auth0' AND issuer = ? AND subject_hash = ?`)
      .bind(providerKind, now, now, issuer, subjectHash)
      .run();
    if (profile.emailVerified && !existing.emailVerifiedAt && existing.email === profile.email) {
      await db.prepare("UPDATE users SET email_verified_at = ?, updated_at = ? WHERE id = ?")
        .bind(now, now, existing.id)
        .run();
      existing.emailVerifiedAt = now;
    }
    if (profile.emailVerified && existing.email !== profile.email) {
      const emailOwner = await db.prepare("SELECT id FROM users WHERE email = ?")
        .bind(profile.email).first<{ id: string }>();
      if (emailOwner && emailOwner.id !== existing.id) {
        throw new Auth0RuntimeError(
          "login_required",
          "Doğrulanmış sağlayıcı e-postası başka bir Panelya hesabıyla çakışıyor.",
          409,
          true,
        );
      }
      await db.prepare("UPDATE users SET email = ?, email_verified_at = ?, updated_at = ? WHERE id = ?")
        .bind(profile.email, now, now, existing.id).run();
      existing.email = profile.email;
      existing.emailVerifiedAt = now;
    }
    await writeAudit(existing.id, "account.provider_login", { provider: "auth0", created: false });
    return existing;
  }

  const emailOwner = await db.prepare("SELECT id FROM users WHERE email = ?").bind(profile.email).first<{ id: string }>();
  if (emailOwner) {
    throw new Auth0RuntimeError(
      "login_required",
      "Bu e-posta mevcut bir Panelya hesabına ait. Hesap ayarlarından güvenli bağlantı yapılmalı.",
      400,
      true,
    );
  }

  const userId = crypto.randomUUID();
  try {
    await db.batch([
      db.prepare(`INSERT INTO users
        (id, email, display_name, password_hash, role, email_verified_at, created_at, updated_at)
        VALUES (?, ?, ?, ?, 'reader', ?, ?, ?)`)
        .bind(
          userId,
          profile.email,
          profile.displayName,
          EXTERNAL_PASSWORD_MARKER,
          profile.emailVerified ? now : null,
          now,
          now,
        ),
      db.prepare(`INSERT INTO provider_identities
        (provider, issuer, subject_hash, provider_kind, user_id, created_at, updated_at, last_login_at)
        VALUES ('auth0', ?, ?, ?, ?, ?, ?, ?)`)
        .bind(issuer, subjectHash, providerKind, userId, now, now, now),
    ]);
  } catch {
    const raced = await findProviderUser(issuer, subjectHash);
    if (raced) return raced;
    throw new Auth0RuntimeError("service_unavailable", "Panelya hesabı oluşturulamadı.", 503, false, 60);
  }
  const user: LocalUser = {
    id: userId,
    email: profile.email,
    displayName: profile.displayName,
    role: "reader",
    emailVerifiedAt: profile.emailVerified ? now : null,
    createdAt: now,
  };
  await writeAudit(user.id, "account.provider_login", { provider: "auth0", created: true });
  return user;
}

function publicAuthUser(user: LocalUser, avatarUrl?: string) {
  return {
    id: user.id,
    displayName: user.displayName,
    email: user.email,
    emailVerified: Boolean(user.emailVerifiedAt),
    role: user.role,
    ...(avatarUrl ? { avatarUrl } : {}),
  };
}

export async function exchangeMobileToken(request: MobileTokenRequest, config: Auth0GatewayConfig) {
  const form = new URLSearchParams({ client_id: config.clientId });
  if (request.grantType === "authorization_code") {
    form.set("grant_type", "authorization_code");
    form.set("code", request.authorizationCode);
    form.set("code_verifier", request.codeVerifier);
    form.set("redirect_uri", request.redirectUri);
  } else {
    form.set("grant_type", "refresh_token");
    form.set("refresh_token", request.refreshToken);
  }

  let response: Response;
  try {
    response = await fetch(config.tokenEndpoint, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded", Accept: "application/json" },
      body: form,
    });
  } catch {
    throw new Auth0RuntimeError("service_unavailable", "Kimlik sağlayıcısına ulaşılamadı.", 503, false, 60);
  }
  const value = await readProviderJson(response);
  if (!response.ok) throw auth0ProviderError(response.status, value);
  const token = value && typeof value === "object" ? value as Auth0TokenPayload : {};
  if (token.token_type !== "Bearer"
    || typeof token.access_token !== "string"
    || token.access_token.length < 16
    || typeof token.refresh_token !== "string"
    || token.refresh_token.length < 16
    || !Number.isInteger(token.expires_in)
    || Number(token.expires_in) < 1
    || Number(token.expires_in) > 3600) {
    throw new Auth0RuntimeError("service_unavailable", "Kimlik sağlayıcısı eksik token cevabı döndürdü.", 503, false, 60);
  }

  const verified = await validateAuth0AccessToken(token.access_token, config);
  const subject = verified.payload.sub as string;
  const profile = await fetchAuth0UserInfo(token.access_token, subject, config);
  const user = await resolveProviderUser(profile, config.issuer);
  const returnedScopes = typeof token.scope === "string"
    ? token.scope.split(/\s+/).filter(Boolean)
    : verified.scopes;
  if (returnedScopes.length === 0) {
    throw new Auth0RuntimeError("service_unavailable", "Kimlik sağlayıcısı izin kapsamı döndürmedi.", 503, false, 60);
  }
  return {
    schemaVersion: "1.0" as const,
    tokenType: "Bearer" as const,
    accessToken: token.access_token,
    expiresIn: Number(token.expires_in),
    refreshToken: token.refresh_token,
    scope: [...new Set(returnedScopes)],
    user: publicAuthUser(user, profile.avatarUrl),
  };
}

export async function revokeMobileToken(refreshToken: string, config: Auth0GatewayConfig) {
  let response: Response;
  try {
    response = await fetch(config.revocationEndpoint, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded", Accept: "application/json" },
      body: new URLSearchParams({
        client_id: config.clientId,
        token: refreshToken,
        token_type_hint: "refresh_token",
      }),
    });
  } catch {
    throw new Auth0RuntimeError("service_unavailable", "Oturum kapatma isteği tamamlanamadı.", 503, false, 60);
  }
  if (!response.ok) throw auth0ProviderError(response.status, await readProviderJson(response));
  return { schemaVersion: "1.0" as const, revoked: true as const };
}

export async function identityFromBearerToken(request: Request, config: Auth0GatewayConfig) {
  const authorization = request.headers.get("authorization");
  if (!authorization) return null;
  const match = /^Bearer ([A-Za-z0-9._~+\/=-]+)$/.exec(authorization);
  if (!match) throw new Auth0RuntimeError("invalid_grant", "Bearer token biçimi geçersiz.", 401, true);
  const verified = await validateAuth0AccessToken(match[1], config);
  const subject = verified.payload.sub as string;
  const subjectHash = await hashOpaqueToken(`${config.issuer}\n${subject}`);
  const identity = await findProviderIdentity(config.issuer, subjectHash);
  if (!identity) throw new Auth0RuntimeError("login_required", "Kimlik Panelya hesabıyla eşlenmemiş.", 401, true);
  const issuedAt = typeof verified.payload.iat === "number" ? verified.payload.iat * 1000 : 0;
  if (identity.status !== "active" || issuedAt < identity.sessionsValidAfter) {
    throw new Auth0RuntimeError("session_revoked", "Oturum artık geçerli değil.", 401, true);
  }
  return {
    ...identity,
    subject,
    subjectHash,
    issuer: config.issuer,
    accessToken: match[1],
    claims: verified.payload,
  };
}

export async function userFromBearerToken(request: Request, config: Auth0GatewayConfig) {
  return (await identityFromBearerToken(request, config))?.user ?? null;
}

export function auth0ErrorResponse(error: unknown) {
  const runtimeError = error instanceof Auth0RuntimeError
    ? error
    : new Auth0RuntimeError("service_unavailable", "Kimlik işlemi tamamlanamadı.", 503, false, 60);
  const headers: Record<string, string> = {
    "Cache-Control": "private, no-store",
    "Referrer-Policy": "no-referrer",
  };
  if (runtimeError.retryAfterSeconds) headers["Retry-After"] = String(runtimeError.retryAfterSeconds);
  return Response.json(
    {
      schemaVersion: "1.0",
      error: runtimeError.code,
      errorDescription: runtimeError.message.slice(0, 240),
      reauthenticate: runtimeError.reauthenticate,
      ...(runtimeError.retryAfterSeconds ? { retryAfterSeconds: runtimeError.retryAfterSeconds } : {}),
    },
    { status: runtimeError.status, headers },
  );
}
