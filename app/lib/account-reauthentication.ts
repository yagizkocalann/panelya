import { CompactEncrypt, compactDecrypt, createRemoteJWKSet, jwtVerify } from "jose";
import { createOpaqueToken, hashOpaqueToken } from "./auth";
import {
  type AccountActor,
  type AccountReauthenticationPurpose,
  AccountRuntimeError,
  hasExactKeys,
} from "./account-runtime";
import { auth0GatewayConfig } from "./auth0-runtime";
import { getDatabase } from "./database";
import { runtimeValue } from "./runtime-config";

type ReauthenticationRequestRow = {
  id: string;
  user_id: string;
  purpose: AccountReauthenticationPurpose;
  transport: "web" | "mobile";
  client_id: string;
  redirect_uri: string;
  code_challenge: string;
  state_hash: string;
  nonce_hash: string;
  expires_at: number;
  used_at: number | null;
};

type ReauthenticationTokenPayload = {
  version: 1;
  jti: string;
  userId: string;
  purpose: AccountReauthenticationPurpose;
  issuer: string;
  subject: string;
  expiresAt: number;
};

const CODE_VERIFIER_PATTERN = /^[A-Za-z0-9\-._~]{43,128}$/;
const CODE_CHALLENGE_PATTERN = /^[A-Za-z0-9_-]{43,128}$/;
const REQUEST_TTL_MS = 5 * 60 * 1000;
const TOKEN_TTL_MS = 10 * 60 * 1000;
const REAUTH_MAX_AGE_SECONDS = 10 * 60;
const jwksByIssuer = new Map<string, ReturnType<typeof createRemoteJWKSet>>();

function callbackScheme(redirectUri: string) {
  return new URL(redirectUri).protocol.replace(/:$/, "");
}

function base64Url(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

async function codeChallenge(verifier: string) {
  return base64Url(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier))));
}

async function runtimeSecretKey() {
  const secret = (await runtimeValue("ACCOUNT_RUNTIME_SECRET")).trim();
  if (secret.length < 32) {
    throw new AccountRuntimeError("service_unavailable", "Hesap kanıt anahtarı yapılandırılmamış.", 503, false, 300);
  }
  return new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(secret)));
}

async function reauthenticationClient(actor: AccountActor, redirectUriValue: string) {
  const gateway = await auth0GatewayConfig();
  if (!gateway) throw new AccountRuntimeError("service_unavailable", "Production kimlik sağlayıcısı etkin değil.", 503, false, 300);
  let redirectUri: string;
  try {
    const url = new URL(redirectUriValue);
    if (url.username || url.password || url.search || url.hash) throw new Error("invalid");
    redirectUri = url.toString();
  } catch {
    throw new AccountRuntimeError("invalid_request", "Geri dönüş adresi geçersiz.", 400);
  }
  if (actor.transport === "mobile") {
    if (!gateway.allowedMobileRedirectUris.has(redirectUri)) {
      throw new AccountRuntimeError("invalid_request", "Geri dönüş adresine izin verilmiyor.", 400);
    }
    return { gateway, clientId: gateway.clientId, clientSecret: "", redirectUri };
  }
  const [clientId, clientSecret, redirectsValue] = await Promise.all([
    runtimeValue("AUTH0_WEB_CLIENT_ID"),
    runtimeValue("AUTH0_WEB_CLIENT_SECRET"),
    runtimeValue("AUTH0_WEB_REDIRECT_URIS"),
  ]);
  const redirects = new Set(redirectsValue.split(",").map((value) => {
    try {
      return new URL(value.trim()).toString();
    } catch {
      return "";
    }
  }).filter(Boolean));
  if (!clientId.trim() || !clientSecret.trim() || !redirects.has(redirectUri)) {
    throw new AccountRuntimeError("service_unavailable", "Web yeniden doğrulama istemcisi yapılandırılmamış.", 503, false, 300);
  }
  return { gateway, clientId: clientId.trim(), clientSecret: clientSecret.trim(), redirectUri };
}

export function parseReauthenticationStart(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new AccountRuntimeError("invalid_request", "Geçersiz yeniden doğrulama isteği.", 400);
  }
  const input = value as Record<string, unknown>;
  if (!hasExactKeys(input, ["purpose", "redirectUri", "codeChallenge", "codeChallengeMethod"])
    || (input.purpose !== "email_change" && input.purpose !== "account_deletion")
    || typeof input.redirectUri !== "string"
    || input.redirectUri.length > 2048
    || typeof input.codeChallenge !== "string"
    || !CODE_CHALLENGE_PATTERN.test(input.codeChallenge)
    || input.codeChallengeMethod !== "S256") {
    throw new AccountRuntimeError("invalid_request", "Yeniden doğrulama alanları geçersiz.", 400);
  }
  return {
    purpose: input.purpose,
    redirectUri: input.redirectUri,
    codeChallenge: input.codeChallenge,
  };
}

export async function startAccountReauthentication(
  actor: AccountActor,
  input: ReturnType<typeof parseReauthenticationStart>,
) {
  if (input.purpose === "email_change" && actor.provider !== "database") {
    throw new AccountRuntimeError("unsupported_action", "E-posta sosyal kimlik sağlayıcısı tarafından yönetiliyor.", 409);
  }
  if (!actor.providerSubjectHash) {
    throw new AccountRuntimeError("unsupported_action", "Bu yerel QA hesabı Auth0 yeniden doğrulamasına bağlı değil.", 409);
  }
  const client = await reauthenticationClient(actor, input.redirectUri);
  const requestId = crypto.randomUUID();
  const state = createOpaqueToken();
  const nonce = createOpaqueToken();
  const now = Date.now();
  const expiresAt = now + REQUEST_TTL_MS;
  const db = await getDatabase();
  await db.prepare(`INSERT INTO account_reauthentication_requests
    (id, user_id, purpose, transport, client_id, redirect_uri, code_challenge, state_hash, nonce_hash, expires_at, used_at, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?)`).bind(
    requestId,
    actor.user.id,
    input.purpose,
    actor.transport,
    client.clientId,
    client.redirectUri,
    input.codeChallenge,
    await hashOpaqueToken(state),
    await hashOpaqueToken(nonce),
    expiresAt,
    now,
  ).run();
  const authorizationUrl = new URL(client.gateway.authorizationEndpoint);
  authorizationUrl.searchParams.set("response_type", "code");
  authorizationUrl.searchParams.set("client_id", client.clientId);
  authorizationUrl.searchParams.set("redirect_uri", client.redirectUri);
  authorizationUrl.searchParams.set("audience", client.gateway.audience);
  authorizationUrl.searchParams.set("scope", "openid profile email");
  authorizationUrl.searchParams.set("state", state);
  authorizationUrl.searchParams.set("nonce", nonce);
  authorizationUrl.searchParams.set("code_challenge", input.codeChallenge);
  authorizationUrl.searchParams.set("code_challenge_method", "S256");
  authorizationUrl.searchParams.set("max_age", "0");
  authorizationUrl.searchParams.set("prompt", "login");
  authorizationUrl.searchParams.set("ui_locales", "tr");
  return {
    schemaVersion: "1.0" as const,
    requestId,
    authorizationUrl: authorizationUrl.toString(),
    callbackUrlScheme: callbackScheme(client.redirectUri),
    expiresAt: new Date(expiresAt).toISOString(),
  };
}

export function parseReauthenticationComplete(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new AccountRuntimeError("invalid_request", "Geçersiz yeniden doğrulama cevabı.", 400);
  }
  const input = value as Record<string, unknown>;
  if (!hasExactKeys(input, ["requestId", "authorizationCode", "state", "codeVerifier", "redirectUri"])
    || typeof input.requestId !== "string"
    || input.requestId.length < 16
    || input.requestId.length > 128
    || typeof input.authorizationCode !== "string"
    || input.authorizationCode.length < 16
    || input.authorizationCode.length > 4096
    || typeof input.state !== "string"
    || input.state.length < 16
    || input.state.length > 512
    || typeof input.codeVerifier !== "string"
    || !CODE_VERIFIER_PATTERN.test(input.codeVerifier)
    || typeof input.redirectUri !== "string"
    || input.redirectUri.length > 2048) {
    throw new AccountRuntimeError("invalid_request", "Yeniden doğrulama cevabı alanları geçersiz.", 400);
  }
  return {
    requestId: input.requestId,
    authorizationCode: input.authorizationCode,
    state: input.state,
    codeVerifier: input.codeVerifier,
    redirectUri: input.redirectUri,
  };
}

function reauthenticationInvalid(message = "Yeniden doğrulama kanıtı geçersiz.") {
  return new AccountRuntimeError("reauthentication_invalid", message, 401, true);
}

async function exchangeReauthenticationCode(
  actor: AccountActor,
  row: ReauthenticationRequestRow,
  authorizationCode: string,
  codeVerifier: string,
) {
  const client = await reauthenticationClient(actor, row.redirect_uri);
  if (client.clientId !== row.client_id) throw reauthenticationInvalid();
  const form = new URLSearchParams({
    grant_type: "authorization_code",
    client_id: row.client_id,
    code: authorizationCode,
    code_verifier: codeVerifier,
    redirect_uri: row.redirect_uri,
  });
  if (client.clientSecret) form.set("client_secret", client.clientSecret);
  let response: Response;
  try {
    response = await fetch(client.gateway.tokenEndpoint, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded", Accept: "application/json" },
      body: form,
    });
  } catch {
    throw new AccountRuntimeError("service_unavailable", "Yeniden doğrulama sağlayıcısına ulaşılamadı.", 503, false, 60);
  }
  let value: unknown;
  try {
    value = await response.json();
  } catch {
    value = null;
  }
  if (!response.ok) throw reauthenticationInvalid("Yetkilendirme kodu geçersiz veya kullanılmış.");
  const body = value && typeof value === "object" ? value as Record<string, unknown> : {};
  if (typeof body.id_token !== "string") {
    throw new AccountRuntimeError("service_unavailable", "Sağlayıcı kimlik kanıtı döndürmedi.", 503, false, 60);
  }
  const jwksUri = new URL(".well-known/jwks.json", client.gateway.issuer).toString();
  let jwks = jwksByIssuer.get(client.gateway.issuer);
  if (!jwks) {
    jwks = createRemoteJWKSet(new URL(jwksUri), { cooldownDuration: 30_000, timeoutDuration: 5_000 });
    jwksByIssuer.set(client.gateway.issuer, jwks);
  }
  let payload;
  try {
    payload = (await jwtVerify(body.id_token, jwks, {
      issuer: client.gateway.issuer,
      audience: row.client_id,
      algorithms: ["RS256"],
      clockTolerance: 5,
    })).payload;
  } catch {
    throw reauthenticationInvalid("Sağlayıcı kimlik kanıtı doğrulanamadı.");
  }
  if (typeof payload.sub !== "string"
    || typeof payload.nonce !== "string"
    || await hashOpaqueToken(payload.nonce) !== row.nonce_hash
    || typeof payload.auth_time !== "number"
    || payload.auth_time * 1000 < Date.now() - REAUTH_MAX_AGE_SECONDS * 1000) {
    throw reauthenticationInvalid("Taze kimlik doğrulama koşulları karşılanmadı.");
  }
  const subjectHash = await hashOpaqueToken(`${client.gateway.issuer}\n${payload.sub}`);
  if (!actor.providerSubjectHash || subjectHash !== actor.providerSubjectHash) {
    throw reauthenticationInvalid("Yeniden doğrulanan kimlik mevcut hesapla eşleşmiyor.");
  }
  return { issuer: client.gateway.issuer, subject: payload.sub };
}

async function encryptReauthenticationToken(payload: ReauthenticationTokenPayload) {
  return new CompactEncrypt(new TextEncoder().encode(JSON.stringify(payload)))
    .setProtectedHeader({ alg: "dir", enc: "A256GCM", typ: "panelya-account-reauth+jwe" })
    .encrypt(await runtimeSecretKey());
}

export async function completeAccountReauthentication(
  actor: AccountActor,
  input: ReturnType<typeof parseReauthenticationComplete>,
) {
  const db = await getDatabase();
  const row = await db.prepare(`SELECT id, user_id, purpose, transport, client_id, redirect_uri,
      code_challenge, state_hash, nonce_hash, expires_at, used_at
    FROM account_reauthentication_requests WHERE id = ?`)
    .bind(input.requestId)
    .first<ReauthenticationRequestRow>();
  if (!row || row.user_id !== actor.user.id || row.transport !== actor.transport) throw reauthenticationInvalid();
  if (row.used_at) throw new AccountRuntimeError("reauthentication_reused", "Yeniden doğrulama isteği daha önce kullanılmış.", 409, true);
  if (row.expires_at <= Date.now()) throw new AccountRuntimeError("reauthentication_expired", "Yeniden doğrulama isteğinin süresi dolmuş.", 401, true);
  let normalizedRedirect: string;
  try {
    normalizedRedirect = new URL(input.redirectUri).toString();
  } catch {
    throw reauthenticationInvalid();
  }
  if (normalizedRedirect !== row.redirect_uri
    || await hashOpaqueToken(input.state) !== row.state_hash
    || await codeChallenge(input.codeVerifier) !== row.code_challenge) {
    throw reauthenticationInvalid();
  }
  const claimed = await db.prepare(`UPDATE account_reauthentication_requests SET used_at = ?
    WHERE id = ? AND used_at IS NULL AND expires_at > ?`).bind(Date.now(), row.id, Date.now()).run();
  if (Number(claimed.meta.changes ?? 0) !== 1) {
    throw new AccountRuntimeError("reauthentication_reused", "Yeniden doğrulama isteği daha önce kullanılmış.", 409, true);
  }
  const provider = await exchangeReauthenticationCode(actor, row, input.authorizationCode, input.codeVerifier);
  const now = Date.now();
  const expiresAt = now + TOKEN_TTL_MS;
  const jti = crypto.randomUUID();
  const rawToken = await encryptReauthenticationToken({
    version: 1,
    jti,
    userId: actor.user.id,
    purpose: row.purpose,
    issuer: provider.issuer,
    subject: provider.subject,
    expiresAt,
  });
  await db.prepare(`INSERT INTO account_reauthentication_tokens
    (token_hash, user_id, purpose, expires_at, used_at, created_at)
    VALUES (?, ?, ?, ?, NULL, ?)`).bind(
    await hashOpaqueToken(rawToken),
    actor.user.id,
    row.purpose,
    expiresAt,
    now,
  ).run();
  return {
    schemaVersion: "1.0" as const,
    purpose: row.purpose,
    reauthenticationToken: rawToken,
    expiresAt: new Date(expiresAt).toISOString(),
  };
}

export async function consumeReauthenticationToken(
  actor: AccountActor,
  purpose: AccountReauthenticationPurpose,
  rawToken: string,
) {
  if (rawToken.length < 32 || rawToken.length > 2048) throw reauthenticationInvalid();
  let payload: ReauthenticationTokenPayload;
  try {
    const decrypted = await compactDecrypt(rawToken, await runtimeSecretKey());
    payload = JSON.parse(new TextDecoder().decode(decrypted.plaintext)) as ReauthenticationTokenPayload;
  } catch {
    throw reauthenticationInvalid();
  }
  if (payload.version !== 1
    || payload.userId !== actor.user.id
    || payload.purpose !== purpose
    || !payload.issuer
    || !payload.subject
    || !Number.isInteger(payload.expiresAt)) {
    throw reauthenticationInvalid();
  }
  if (payload.expiresAt <= Date.now()) {
    throw new AccountRuntimeError("reauthentication_expired", "Yeniden doğrulama kanıtının süresi dolmuş.", 401, true);
  }
  const subjectHash = await hashOpaqueToken(`${payload.issuer}\n${payload.subject}`);
  if (!actor.providerSubjectHash || subjectHash !== actor.providerSubjectHash) throw reauthenticationInvalid();
  const db = await getDatabase();
  const consumed = await db.prepare(`UPDATE account_reauthentication_tokens SET used_at = ?
    WHERE token_hash = ? AND user_id = ? AND purpose = ? AND used_at IS NULL AND expires_at > ?`)
    .bind(Date.now(), await hashOpaqueToken(rawToken), actor.user.id, purpose, Date.now()).run();
  if (Number(consumed.meta.changes ?? 0) !== 1) {
    const row = await db.prepare("SELECT used_at, expires_at FROM account_reauthentication_tokens WHERE token_hash = ?")
      .bind(await hashOpaqueToken(rawToken)).first<{ used_at: number | null; expires_at: number }>();
    if (row?.used_at) throw new AccountRuntimeError("reauthentication_reused", "Yeniden doğrulama kanıtı daha önce kullanılmış.", 409, true);
    if (row && row.expires_at <= Date.now()) {
      throw new AccountRuntimeError("reauthentication_expired", "Yeniden doğrulama kanıtının süresi dolmuş.", 401, true);
    }
    throw reauthenticationInvalid();
  }
  return { issuer: payload.issuer, subject: payload.subject };
}
