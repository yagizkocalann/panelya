import assert from "node:assert/strict";
import test from "node:test";

Object.assign(process.env, {
  AUTH0_GATEWAY_ENABLED: "true",
  AUTH0_ISSUER: "https://panelya-test.eu.auth0.com/",
  AUTH0_MOBILE_CLIENT_ID: "panelya_mobile_public_client",
  AUTH0_AUDIENCE: "https://api.panelya.test",
  AUTH0_MOBILE_REDIRECT_URIS: "panelya://auth/callback",
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
