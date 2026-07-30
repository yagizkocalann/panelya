import { CompactEncrypt, compactDecrypt } from "jose";
import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import {
  createOpaqueToken,
  createSession,
  getCurrentUser,
  hasRecentAuthentication,
  safeReturnTo,
} from "./auth";
import { setSessionCookie } from "./auth-http";
import {
  auth0GatewayConfig,
  Auth0RuntimeError,
  linkAuth0ProviderIdentity,
  resolveAuth0ProviderEvidence,
  resolveAuth0ProviderSession,
  validateAuth0IdToken,
} from "./auth0-runtime";
import { runtimeValue } from "./runtime-config";

const WEB_AUTH_COOKIE = "panelya_auth_web_state";
const WEB_AUTH_TTL_MS = 10 * 60 * 1000;

type WebAuthState = {
  version: 1;
  state: string;
  nonce: string;
  codeVerifier: string;
  redirectUri: string;
  returnTo: string;
  remember: boolean;
  purpose: "login" | "link";
  linkUserId?: string;
  expiresAt: number;
};

type Auth0WebConfig = {
  gateway: NonNullable<Awaited<ReturnType<typeof auth0GatewayConfig>>>;
  clientId: string;
  clientSecret: string;
  redirectUri: string;
};

function base64Url(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

async function webStateKey() {
  const secret = (await runtimeValue("ACCOUNT_RUNTIME_SECRET")).trim();
  if (secret.length < 32) {
    throw new Auth0RuntimeError("service_unavailable", "Web oturum anahtarı yapılandırılmamış.", 503, false, 300);
  }
  return new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(secret)));
}

function exactCallbackUrl(request: Request) {
  const callback = new URL("/api/auth/web/callback", request.url);
  callback.search = "";
  callback.hash = "";
  return callback.toString();
}

function allowedUrlSet(value: string) {
  return new Set(value.split(",").map((candidate) => {
    try {
      const url = new URL(candidate.trim());
      if (url.username || url.password || url.search || url.hash) return "";
      return url.toString();
    } catch {
      return "";
    }
  }).filter(Boolean));
}

export async function auth0WebConfig(request: Request): Promise<Auth0WebConfig | null> {
  const [gateway, clientId, clientSecret, redirectsValue] = await Promise.all([
    auth0GatewayConfig(),
    runtimeValue("AUTH0_WEB_CLIENT_ID"),
    runtimeValue("AUTH0_WEB_CLIENT_SECRET"),
    runtimeValue("AUTH0_WEB_REDIRECT_URIS"),
  ]);
  if (!gateway || !clientId.trim() || !clientSecret.trim()) return null;
  const redirectUri = exactCallbackUrl(request);
  if (!allowedUrlSet(redirectsValue).has(redirectUri)) return null;
  return { gateway, clientId: clientId.trim(), clientSecret: clientSecret.trim(), redirectUri };
}

export async function isAuth0WebEnabled(origin: string) {
  return Boolean(await auth0WebConfig(new Request(new URL("/login", origin))));
}

export async function auth0WebLogoutUrl(request: Request, returnTo: string) {
  const [config, logoutUrisValue] = await Promise.all([
    auth0WebConfig(request),
    runtimeValue("AUTH0_WEB_LOGOUT_URIS"),
  ]);
  if (!config) return null;
  const localReturnUrl = new URL(safeReturnTo(returnTo, "/"), request.url).toString();
  if (!allowedUrlSet(logoutUrisValue).has(localReturnUrl)) return null;
  const logoutUrl = new URL("v2/logout", config.gateway.issuer);
  logoutUrl.searchParams.set("client_id", config.clientId);
  logoutUrl.searchParams.set("returnTo", localReturnUrl);
  return logoutUrl;
}

async function encryptState(payload: WebAuthState) {
  return new CompactEncrypt(new TextEncoder().encode(JSON.stringify(payload)))
    .setProtectedHeader({ alg: "dir", enc: "A256GCM", typ: "panelya-web-auth+jwe" })
    .encrypt(await webStateKey());
}

async function decryptState(raw: string) {
  try {
    const decrypted = await compactDecrypt(raw, await webStateKey());
    const value = JSON.parse(new TextDecoder().decode(decrypted.plaintext)) as WebAuthState;
    if (value.version !== 1
      || typeof value.state !== "string"
      || typeof value.nonce !== "string"
      || typeof value.codeVerifier !== "string"
      || typeof value.redirectUri !== "string"
      || typeof value.returnTo !== "string"
      || typeof value.remember !== "boolean"
      || (value.purpose !== "login" && value.purpose !== "link")
      || (value.linkUserId !== undefined && typeof value.linkUserId !== "string")
      || (value.purpose === "link" && !value.linkUserId)
      || !Number.isInteger(value.expiresAt)) {
      throw new Error("invalid");
    }
    return value;
  } catch {
    throw new Auth0RuntimeError("invalid_grant", "Web giriş isteği geçersiz veya süresi dolmuş.", 400, true);
  }
}

export function clearAuth0WebState(response: NextResponse) {
  response.cookies.set(WEB_AUTH_COOKIE, "", {
    httpOnly: true,
    sameSite: "lax",
    path: "/api/auth/web/callback",
    expires: new Date(0),
  });
}

export async function startAuth0WebLogin(
  request: Request,
  input: {
    returnTo: string;
    remember: boolean;
    screenHint?: "signup";
    purpose?: "login" | "link";
    linkUserId?: string;
  },
) {
  const config = await auth0WebConfig(request);
  if (!config) {
    throw new Auth0RuntimeError("service_unavailable", "Web kimlik sağlayıcısı yapılandırılmamış.", 503, false, 300);
  }
  const state = createOpaqueToken();
  const nonce = createOpaqueToken();
  const codeVerifier = base64Url(crypto.getRandomValues(new Uint8Array(64)));
  const codeChallenge = base64Url(new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(codeVerifier)),
  ));
  const expiresAt = Date.now() + WEB_AUTH_TTL_MS;
  const purpose = input.purpose ?? "login";
  if (purpose === "link" && !input.linkUserId) {
    throw new Auth0RuntimeError("invalid_grant", "Hesap bağlantısı için etkin oturum gerekli.", 401, true);
  }
  const authorizationUrl = new URL(config.gateway.authorizationEndpoint);
  authorizationUrl.searchParams.set("response_type", "code");
  authorizationUrl.searchParams.set("client_id", config.clientId);
  authorizationUrl.searchParams.set("redirect_uri", config.redirectUri);
  authorizationUrl.searchParams.set("audience", config.gateway.audience);
  authorizationUrl.searchParams.set("scope", "openid profile email");
  authorizationUrl.searchParams.set("state", state);
  authorizationUrl.searchParams.set("nonce", nonce);
  authorizationUrl.searchParams.set("code_challenge", codeChallenge);
  authorizationUrl.searchParams.set("code_challenge_method", "S256");
  authorizationUrl.searchParams.set("ui_locales", "tr");
  if (purpose === "link") {
    authorizationUrl.searchParams.set("prompt", "login");
    authorizationUrl.searchParams.set("max_age", "0");
  }
  if (input.screenHint) authorizationUrl.searchParams.set("screen_hint", input.screenHint);

  const response = NextResponse.redirect(authorizationUrl, 303);
  response.headers.set("Cache-Control", "private, no-store");
  response.headers.set("Referrer-Policy", "no-referrer");
  response.cookies.set(WEB_AUTH_COOKIE, await encryptState({
    version: 1,
    state,
    nonce,
    codeVerifier,
    redirectUri: config.redirectUri,
    returnTo: safeReturnTo(input.returnTo, "/account"),
    remember: input.remember,
    purpose,
    ...(input.linkUserId ? { linkUserId: input.linkUserId } : {}),
    expiresAt,
  }), {
    httpOnly: true,
    sameSite: "lax",
    secure: new URL(request.url).protocol === "https:",
    path: "/api/auth/web/callback",
    expires: new Date(expiresAt),
  });
  return response;
}

async function exchangeWebCode(
  config: Auth0WebConfig,
  state: WebAuthState,
  authorizationCode: string,
) {
  let response: Response;
  try {
    response = await fetch(config.gateway.tokenEndpoint, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded", Accept: "application/json" },
      body: new URLSearchParams({
        grant_type: "authorization_code",
        client_id: config.clientId,
        client_secret: config.clientSecret,
        code: authorizationCode,
        code_verifier: state.codeVerifier,
        redirect_uri: state.redirectUri,
      }),
    });
  } catch {
    throw new Auth0RuntimeError("service_unavailable", "Web kimlik sağlayıcısına ulaşılamadı.", 503, false, 60);
  }
  let value: unknown;
  try {
    value = await response.json();
  } catch {
    value = null;
  }
  const token = value && typeof value === "object" ? value as Record<string, unknown> : {};
  if (!response.ok
    || token.token_type !== "Bearer"
    || typeof token.access_token !== "string"
    || typeof token.id_token !== "string") {
    throw new Auth0RuntimeError("invalid_grant", "Web yetkilendirme kodu geçersiz veya kullanılmış.", 400, true);
  }
  return { accessToken: token.access_token, idToken: token.id_token };
}

export async function completeAuth0WebLogin(request: Request) {
  const url = new URL(request.url);
  if (url.searchParams.get("error")) {
    throw new Auth0RuntimeError("login_required", "Auth0 giriş işlemi tamamlanmadı.", 401, true);
  }
  const authorizationCode = url.searchParams.get("code") ?? "";
  const returnedState = url.searchParams.get("state") ?? "";
  if (authorizationCode.length < 16 || returnedState.length < 16) {
    throw new Auth0RuntimeError("invalid_grant", "Web callback alanları eksik.", 400, true);
  }
  const cookieStore = await cookies();
  const state = await decryptState(cookieStore.get(WEB_AUTH_COOKIE)?.value ?? "");
  if (state.expiresAt <= Date.now()
    || state.state !== returnedState
    || state.redirectUri !== exactCallbackUrl(request)) {
    throw new Auth0RuntimeError("invalid_grant", "Web giriş isteği eşleşmiyor veya süresi dolmuş.", 400, true);
  }
  const config = await auth0WebConfig(request);
  if (!config || config.redirectUri !== state.redirectUri) {
    throw new Auth0RuntimeError("service_unavailable", "Web kimlik sağlayıcısı yapılandırılmamış.", 503, false, 300);
  }
  const token = await exchangeWebCode(config, state, authorizationCode);
  const idToken = await validateAuth0IdToken(token.idToken, config.gateway, config.clientId, state.nonce);
  if (state.purpose === "link") {
    const authenticatedAt = typeof idToken.auth_time === "number" ? idToken.auth_time * 1000 : 0;
    if (authenticatedAt < Date.now() - WEB_AUTH_TTL_MS || authenticatedAt > Date.now() + 30_000) {
      throw new Auth0RuntimeError("login_required", "Auth0 hesap bağlantısı taze giriş doğrulaması gerektirir.", 401, true);
    }
    const [currentUser, recentAuthentication, evidence] = await Promise.all([
      getCurrentUser(),
      hasRecentAuthentication(),
      resolveAuth0ProviderEvidence(token.accessToken, config.gateway, config.clientId),
    ]);
    if (!currentUser || currentUser.id !== state.linkUserId || !recentAuthentication) {
      throw new Auth0RuntimeError("login_required", "Hesap bağlantısı için mevcut oturumunu yeniden doğrulamalısın.", 401, true);
    }
    if (idToken.sub !== evidence.subject) {
      throw new Auth0RuntimeError("invalid_grant", "Web kimlik kanıtları aynı hesaba ait değil.", 401, true);
    }
    await linkAuth0ProviderIdentity(currentUser, evidence, config.gateway.issuer);
    const response = NextResponse.redirect(new URL(state.returnTo, request.url), 303);
    clearAuth0WebState(response);
    response.headers.set("Cache-Control", "private, no-store");
    response.headers.set("Referrer-Policy", "no-referrer");
    return response;
  } else {
    const identity = await resolveAuth0ProviderSession(token.accessToken, config.gateway, config.clientId);
    if (idToken.sub !== identity.subject) {
      throw new Auth0RuntimeError("invalid_grant", "Web kimlik kanıtları aynı hesaba ait değil.", 401, true);
    }
    const session = await createSession(identity.user.id, state.remember, request);
    const response = NextResponse.redirect(new URL(state.returnTo, request.url), 303);
    setSessionCookie(response, request, session.rawToken, session.expiresAt);
    clearAuth0WebState(response);
    response.headers.set("Cache-Control", "private, no-store");
    response.headers.set("Referrer-Policy", "no-referrer");
    return response;
  }
}
