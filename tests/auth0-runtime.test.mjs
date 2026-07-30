import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

Object.assign(process.env, {
  AUTH0_GATEWAY_ENABLED: "true",
  AUTH0_ISSUER: "https://panelya-test.eu.auth0.com/",
  AUTH0_MOBILE_CLIENT_ID: "panelya_mobile_public_client",
  AUTH0_AUDIENCE: "https://api.panelya.test",
  AUTH0_MOBILE_REDIRECT_URIS: "panelya://auth/callback",
  AUTH0_WEB_CLIENT_ID: "panelya_web_confidential_client",
  AUTH0_WEB_CLIENT_SECRET: "fixture_web_secret_never_valid",
  AUTH0_WEB_REDIRECT_URIS: "http://localhost/api/auth/web/callback,http://localhost:3000/api/auth/web/callback",
  AUTH0_WEB_LOGOUT_URIS: "http://localhost/",
  ACCOUNT_RUNTIME_SECRET: "fixture-account-runtime-secret-at-least-32-characters",
});

const workerUrl = new URL("../dist/server/index.js", import.meta.url);
workerUrl.searchParams.set("auth0-runtime-test", `${process.pid}-${Date.now()}`);
const { default: worker } = await import(workerUrl.href);

const authEnv = {
  ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) },
  AUTH0_GATEWAY_ENABLED: process.env.AUTH0_GATEWAY_ENABLED,
  AUTH0_ISSUER: process.env.AUTH0_ISSUER,
  AUTH0_MOBILE_CLIENT_ID: process.env.AUTH0_MOBILE_CLIENT_ID,
  AUTH0_AUDIENCE: process.env.AUTH0_AUDIENCE,
  AUTH0_MOBILE_REDIRECT_URIS: process.env.AUTH0_MOBILE_REDIRECT_URIS,
  AUTH0_WEB_CLIENT_ID: process.env.AUTH0_WEB_CLIENT_ID,
  AUTH0_WEB_CLIENT_SECRET: process.env.AUTH0_WEB_CLIENT_SECRET,
  AUTH0_WEB_REDIRECT_URIS: process.env.AUTH0_WEB_REDIRECT_URIS,
  AUTH0_WEB_LOGOUT_URIS: process.env.AUTH0_WEB_LOGOUT_URIS,
  ACCOUNT_RUNTIME_SECRET: process.env.ACCOUNT_RUNTIME_SECRET,
};

const executionContext = {
  waitUntil() {},
  passThroughOnException() {},
};

test("configured Auth0 gateway publishes only public native configuration", async () => {
  const response = await worker.fetch(
    new Request("http://localhost/api/auth/config", { headers: { accept: "application/json" } }),
    authEnv,
    executionContext,
  );
  assert.equal(response.status, 200);
  assert.match(response.headers.get("cache-control") ?? "", /no-store/);
  const config = await response.json();
  assert.deepEqual(config, {
    schemaVersion: "1.0",
    provider: "auth0",
    flow: "authorization_code_pkce",
    issuer: authEnv.AUTH0_ISSUER,
    clientId: authEnv.AUTH0_MOBILE_CLIENT_ID,
    audience: authEnv.AUTH0_AUDIENCE,
    scopes: [
      "openid",
      "profile",
      "email",
      "offline_access",
      "read:library",
      "write:library",
      "write:progress",
      "write:community",
    ],
    authorizationEndpoint: `${authEnv.AUTH0_ISSUER}authorize`,
    tokenEndpoint: `${authEnv.AUTH0_ISSUER}oauth/token`,
    revocationEndpoint: `${authEnv.AUTH0_ISSUER}oauth/revoke`,
    accessTokenLifetimeSeconds: 900,
    refreshTokenRotation: true,
  });
  assert.doesNotMatch(JSON.stringify(config), /secret|management|private.?key/i);
});

test("mobile token gateway rejects redirect URIs outside the exact allowlist", async () => {
  const response = await worker.fetch(
    new Request("http://localhost/api/auth/mobile/token", {
      method: "POST",
      headers: { accept: "application/json", "content-type": "application/json" },
      body: JSON.stringify({
        grantType: "authorization_code",
        authorizationCode: "fixture_authorization_code_never_valid",
        codeVerifier: "a".repeat(43),
        redirectUri: "evil-app://auth/callback",
      }),
    }),
    authEnv,
    executionContext,
  );
  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), {
    schemaVersion: "1.0",
    error: "invalid_grant",
    errorDescription: "Geri dönüş adresine izin verilmiyor.",
    reauthenticate: true,
  });
});

test("mobile revoke gateway rejects unknown fields before contacting Auth0", async () => {
  const response = await worker.fetch(
    new Request("http://localhost/api/auth/mobile/revoke", {
      method: "POST",
      headers: { accept: "application/json", "content-type": "application/json" },
      body: JSON.stringify({
        refreshToken: "fixture_refresh_token_never_valid",
        clientSecret: "must-not-be-accepted",
      }),
    }),
    authEnv,
    executionContext,
  );
  assert.equal(response.status, 400);
  const error = await response.json();
  assert.equal(error.error, "invalid_grant");
  assert.equal(error.reauthenticate, true);
});

test("web BFF source binds opaque state, nonce and PKCE to an encrypted host transaction", async () => {
  const source = await readFile(new URL("../app/lib/auth0-web.ts", import.meta.url), "utf8");
  assert.match(source, /new CompactEncrypt/);
  assert.match(source, /compactDecrypt/);
  assert.match(source, /searchParams\.set\("state", state\)/);
  assert.match(source, /searchParams\.set\("nonce", nonce\)/);
  assert.match(source, /searchParams\.set\("code_challenge", codeChallenge\)/);
  assert.match(source, /searchParams\.set\("code_challenge_method", "S256"\)/);
  assert.match(source, /client_secret: config\.clientSecret/);
  assert.match(source, /httpOnly: true/);
  assert.match(source, /sameSite: "lax"/);
  assert.match(source, /path: "\/api\/auth\/web\/callback"/);
  assert.doesNotMatch(source, /searchParams\.set\("client_secret"/);
});

test("web BFF callback fails closed without its encrypted transaction cookie", async () => {
  const response = await worker.fetch(
    new Request(`http://localhost/api/auth/web/callback?code=${"a".repeat(24)}&state=${"b".repeat(24)}`, {
      redirect: "manual",
    }),
    authEnv,
    executionContext,
  );
  assert.equal(response.status, 303);
  const location = new URL(response.headers.get("location"));
  assert.equal(location.pathname, "/login");
  assert.match(location.searchParams.get("error") ?? "", /geçersiz|süresi dolmuş/i);
  assert.match(response.headers.get("set-cookie") ?? "", /panelya_auth_web_state=;/);
});

test("web logout clears the host-only session and delegates SSO logout to an exact allowlisted URL", async () => {
  const response = await worker.fetch(
    new Request("http://localhost/api/auth/logout", {
      method: "POST",
      headers: {
        origin: "http://localhost",
        "content-type": "application/x-www-form-urlencoded",
        "x-forwarded-for": `203.0.113.${(process.pid % 200) + 1}`,
      },
      body: new URLSearchParams({ return_to: "/" }),
      redirect: "manual",
    }),
    authEnv,
    executionContext,
  );
  assert.equal(response.status, 303);
  const location = new URL(response.headers.get("location"));
  assert.equal(location.origin, "https://panelya-test.eu.auth0.com");
  assert.equal(location.pathname, "/v2/logout");
  assert.equal(location.searchParams.get("client_id"), authEnv.AUTH0_WEB_CLIENT_ID);
  assert.equal(location.searchParams.get("returnTo"), authEnv.AUTH0_WEB_LOGOUT_URIS);
  assert.match(response.headers.get("set-cookie") ?? "", /panelya_session=;/);
});

test("web login and explicit provider linking remain separate, fail-closed flows", async () => {
  const [webSource, runtimeSource, linkRoute] = await Promise.all([
    readFile(new URL("../app/lib/auth0-web.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/auth0-runtime.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/auth/web/link/route.ts", import.meta.url), "utf8"),
  ]);
  assert.match(webSource, /state\.purpose === "link"/);
  assert.match(webSource, /searchParams\.set\("prompt", "login"\)/);
  assert.match(webSource, /searchParams\.set\("max_age", "0"\)/);
  assert.match(webSource, /idToken\.auth_time/);
  assert.match(webSource, /currentUser\.id !== state\.linkUserId/);
  assert.match(webSource, /hasRecentAuthentication/);
  assert.match(runtimeSource, /evidence\.profile\.emailVerified/);
  assert.match(runtimeSource, /evidence\.profile\.email !== user\.email/);
  assert.match(runtimeSource, /Bu e-posta mevcut bir Panelya hesabına ait/);
  assert.match(linkRoute, /assertSameOrigin/);

  const loginPage = await worker.fetch(
    new Request("http://localhost/login"),
    authEnv,
    executionContext,
  );
  assert.equal(loginPage.status, 200);
  const html = await loginPage.text();
  assert.match(html, /action="\/api\/auth\/web\/login"/);
  assert.match(html, /Panelya şifreni görmez veya saklamaz/);
  assert.doesNotMatch(html, /name="password"/);

  const linkWithoutSession = await worker.fetch(
    new Request("http://localhost/api/auth/web/link", {
      method: "POST",
      headers: { origin: "http://localhost" },
      redirect: "manual",
    }),
    authEnv,
    executionContext,
  );
  assert.equal(linkWithoutSession.status, 401);
  assert.match(await linkWithoutSession.text(), /giriş yapmalısın/i);
});
