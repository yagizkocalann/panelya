import { assertSameOrigin, getCurrentSessionHash, getCurrentUser, hashOpaqueToken, normalizeEmail, type LocalUser } from "./auth";
import {
  auth0GatewayConfig,
  Auth0RuntimeError,
  identityFromBearerToken,
  type AccountProviderKind,
} from "./auth0-runtime";
import { getDatabase, writeAudit } from "./database";
import { runtimeValue } from "./runtime-config";

export type AccountTransport = "web" | "mobile";
export type AccountReauthenticationPurpose = "email_change" | "account_deletion";

export type AccountActor = {
  user: LocalUser;
  transport: AccountTransport;
  provider: AccountProviderKind;
  currentSessionHash: string | null;
  issuer: string | null;
  providerSubject: string | null;
  providerSubjectHash: string | null;
};

export type AccountErrorCode =
  | "not_authenticated"
  | "invalid_request"
  | "unsupported_action"
  | "reauthentication_required"
  | "reauthentication_invalid"
  | "reauthentication_expired"
  | "reauthentication_reused"
  | "not_found"
  | "conflict"
  | "rate_limited"
  | "service_unavailable";

export class AccountRuntimeError extends Error {
  constructor(
    public readonly code: AccountErrorCode,
    message: string,
    public readonly status: number,
    public readonly reauthenticate = false,
    public readonly retryAfterSeconds?: number,
  ) {
    super(message);
    this.name = "AccountRuntimeError";
  }
}

type ProviderKindRow = {
  provider_kind: AccountProviderKind;
  issuer: string;
  subject_hash: string;
};

function accountHeaders(retryAfterSeconds?: number) {
  return {
    "Cache-Control": "private, no-store",
    "Referrer-Policy": "no-referrer",
    ...(retryAfterSeconds ? { "Retry-After": String(retryAfterSeconds) } : {}),
  };
}

export function accountErrorResponse(error: unknown) {
  if (error instanceof Auth0RuntimeError) {
    const code: AccountErrorCode = error.code === "rate_limited"
      ? "rate_limited"
      : error.code === "service_unavailable"
        ? "service_unavailable"
        : "not_authenticated";
    return Response.json({
      schemaVersion: "1.0",
      error: code,
      errorDescription: error.message.slice(0, 240),
      reauthenticate: error.reauthenticate,
      ...(error.retryAfterSeconds ? { retryAfterSeconds: error.retryAfterSeconds } : {}),
    }, { status: error.status, headers: accountHeaders(error.retryAfterSeconds) });
  }
  const runtimeError = error instanceof AccountRuntimeError
    ? error
    : new AccountRuntimeError("service_unavailable", "Hesap işlemi tamamlanamadı.", 503, false, 60);
  return Response.json({
    schemaVersion: "1.0",
    error: runtimeError.code,
    errorDescription: runtimeError.message.slice(0, 240),
    reauthenticate: runtimeError.reauthenticate,
    ...(runtimeError.retryAfterSeconds ? { retryAfterSeconds: runtimeError.retryAfterSeconds } : {}),
  }, { status: runtimeError.status, headers: accountHeaders(runtimeError.retryAfterSeconds) });
}

export async function readLimitedAccountJson(request: Request, maximumBytes = 16_384) {
  if (!(request.headers.get("content-type") ?? "").toLowerCase().startsWith("application/json")) {
    throw new AccountRuntimeError("invalid_request", "İstek JSON olmalı.", 400);
  }
  const declaredLength = Number(request.headers.get("content-length") ?? 0);
  if (Number.isFinite(declaredLength) && declaredLength > maximumBytes) {
    throw new AccountRuntimeError("invalid_request", "İstek gövdesi çok büyük.", 400);
  }
  if (!request.body) throw new AccountRuntimeError("invalid_request", "İstek gövdesi eksik.", 400);
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    totalBytes += value.byteLength;
    if (totalBytes > maximumBytes) {
      await reader.cancel();
      throw new AccountRuntimeError("invalid_request", "İstek gövdesi çok büyük.", 400);
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
    throw new AccountRuntimeError("invalid_request", "Geçerli bir JSON gövdesi gönderilmeli.", 400);
  }
}

export function hasExactKeys(value: Record<string, unknown>, expected: readonly string[]) {
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  return actual.length === wanted.length && actual.every((key, index) => key === wanted[index]);
}

export function objectInput(value: unknown, expectedKeys: readonly string[]) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new AccountRuntimeError("invalid_request", "Geçersiz istek.", 400);
  }
  const input = value as Record<string, unknown>;
  if (!hasExactKeys(input, expectedKeys)) {
    throw new AccountRuntimeError("invalid_request", "İstek alanları sözleşmeyle eşleşmiyor.", 400);
  }
  return input;
}

async function webProviderIdentity(userId: string) {
  const db = await getDatabase();
  return db.prepare(`SELECT provider_kind, issuer, subject_hash
    FROM provider_identities WHERE user_id = ? AND provider = 'auth0'`)
    .bind(userId)
    .first<ProviderKindRow>();
}

export async function getAccountActor(
  request: Request,
  requiredScopes: readonly string[] = [],
): Promise<AccountActor | null> {
  if (request.headers.has("authorization")) {
    const config = await auth0GatewayConfig();
    if (!config) throw new AccountRuntimeError("service_unavailable", "Production kimlik sağlayıcısı etkin değil.", 503, false, 300);
    const identity = await identityFromBearerToken(request, config, requiredScopes);
    if (!identity) return null;
    return {
      user: identity.user,
      transport: "mobile",
      provider: identity.providerKind,
      currentSessionHash: null,
      issuer: identity.issuer,
      providerSubject: identity.subject,
      providerSubjectHash: identity.subjectHash,
    };
  }

  const user = await getCurrentUser();
  if (!user) return null;
  const identity = await webProviderIdentity(user.id);
  return {
    user,
    transport: "web",
    provider: identity?.provider_kind ?? "database",
    currentSessionHash: await getCurrentSessionHash(),
    issuer: identity?.issuer ?? null,
    providerSubject: null,
    providerSubjectHash: identity?.subject_hash ?? null,
  };
}

export async function requireAccountActor(
  request: Request,
  requiredScopes: readonly string[] = [],
) {
  const actor = await getAccountActor(request, requiredScopes);
  if (!actor) throw new AccountRuntimeError("not_authenticated", "Bu işlem için giriş yapmalısın.", 401, true);
  return actor;
}

export function assertAccountMutationOrigin(request: Request, actor: AccountActor) {
  if (actor.transport !== "web") return;
  try {
    assertSameOrigin(request);
  } catch {
    throw new AccountRuntimeError("invalid_request", "İstek kaynağı doğrulanamadı.", 403);
  }
}

export function accountCapabilities(provider: AccountProviderKind) {
  const providerManaged = provider === "database" ? null : "provider_managed" as const;
  return {
    profileEditing: "enabled" as const,
    avatarEditing: providerManaged ?? "unavailable" as const,
    emailChange: "unavailable" as const,
    passwordAction: providerManaged ?? "enabled" as const,
    sessionManagement: "enabled" as const,
    blockedAccounts: "enabled" as const,
    accountDeletion: "reauthentication_required" as const,
  };
}

export function accountOverview(actor: AccountActor) {
  return {
    schemaVersion: "1.0" as const,
    user: {
      id: actor.user.id,
      displayName: actor.user.displayName,
      email: actor.user.email,
      emailVerified: Boolean(actor.user.emailVerifiedAt),
      role: actor.user.role,
    },
    provider: actor.provider,
    capabilities: accountCapabilities(actor.provider),
  };
}

export async function updateAccountProfile(actor: AccountActor, displayNameValue: unknown) {
  if (typeof displayNameValue !== "string") {
    throw new AccountRuntimeError("invalid_request", "Görünen ad metin olmalı.", 400);
  }
  const displayName = displayNameValue.trim();
  if (displayName.length < 2 || displayName.length > 80) {
    throw new AccountRuntimeError("invalid_request", "Görünen ad 2–80 karakter olmalı.", 400);
  }
  const db = await getDatabase();
  const now = Date.now();
  const result = await db.prepare(`UPDATE users SET display_name = ?, updated_at = ?
    WHERE id = ? AND status = 'active'`).bind(displayName, now, actor.user.id).run();
  if (Number(result.meta.changes ?? 0) !== 1) {
    throw new AccountRuntimeError("not_found", "Hesap bulunamadı.", 404);
  }
  actor.user.displayName = displayName;
  await writeAudit(actor.user.id, "account.profile_updated", { transport: actor.transport });
  return accountOverview(actor);
}

export function normalizeAccountEmail(value: unknown) {
  if (typeof value !== "string") {
    throw new AccountRuntimeError("invalid_request", "E-posta adresi metin olmalı.", 400);
  }
  const email = normalizeEmail(value);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) {
    throw new AccountRuntimeError("invalid_request", "Geçerli bir e-posta adresi gir.", 400);
  }
  return email;
}

export async function publicSessionId(kind: "web" | "native", credentialId: string, secret: string) {
  return `${kind === "web" ? "w" : "n"}_${(await hashOpaqueToken(`${secret}\n${kind}\n${credentialId}`))
    .replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "")}`;
}

export async function accountRuntimeSecret() {
  const secret = (await runtimeValue("ACCOUNT_RUNTIME_SECRET")).trim();
  if (secret.length < 32) {
    throw new AccountRuntimeError("service_unavailable", "Hesap çalışma anahtarı yapılandırılmamış.", 503, false, 300);
  }
  return secret;
}

export const ACCOUNT_JSON_HEADERS = accountHeaders();
