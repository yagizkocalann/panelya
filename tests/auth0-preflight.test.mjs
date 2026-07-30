import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import {
  parseEnvText,
  validateAuth0LiveReadiness,
} from "../scripts/verify-auth0-live-readiness.mjs";

const readyConfig = {
  AUTH0_GATEWAY_ENABLED: "true",
  AUTH0_ISSUER: "https://tenant.example.auth0.com/",
  AUTH0_MOBILE_CLIENT_ID: "fixture_native_client",
  AUTH0_AUDIENCE: "https://api.example.test",
  AUTH0_MOBILE_REDIRECT_URIS: "panelya://auth/callback",
  AUTH0_WEB_CLIENT_ID: "fixture_web_client",
  AUTH0_WEB_CLIENT_SECRET: "fixture_web_secret",
  AUTH0_WEB_REDIRECT_URIS: [
    "http://localhost:3000/api/auth/web/callback",
    "http://localhost:3000/account/reauthentication/callback",
  ].join(","),
  AUTH0_WEB_LOGOUT_URIS: "http://localhost:3000",
  AUTH0_MANAGEMENT_CLIENT_ID: "fixture_management_client",
  AUTH0_MANAGEMENT_CLIENT_SECRET: "fixture_management_secret",
  AUTH0_MANAGEMENT_AUDIENCE: "https://tenant.example.auth0.com/api/v2/",
  AUTH0_DATABASE_CONNECTION: "Username-Password-Authentication",
  ACCOUNT_RUNTIME_SECRET: "fixture-account-runtime-secret-at-least-32-characters",
};

test("Auth0 canlı ön kontrolü exact web ve native callback sınırını kabul eder", () => {
  const result = validateAuth0LiveReadiness(readyConfig, "http://localhost:3000");
  assert.equal(result.ready, true);
  assert.deepEqual(result.requiredManagementScopes, [
    "read:users",
    "update:users",
    "delete:users",
    "read:device_credentials",
    "delete:device_credentials",
  ]);
});

test("Auth0 canlı ön kontrolü eksik ikinci web callback'inde fail-closed kalır", () => {
  const result = validateAuth0LiveReadiness({
    ...readyConfig,
    AUTH0_WEB_REDIRECT_URIS: "http://localhost:3000/api/auth/web/callback",
  }, "http://localhost:3000");
  assert.equal(result.ready, false);
  assert.equal(result.checks.find((item) => item.id === "web-callbacks")?.status, "missing");
});

test("Auth0 canlı ön kontrolü kısa runtime secret ve yanlış mobile callback'i reddeder", () => {
  const result = validateAuth0LiveReadiness({
    ...readyConfig,
    AUTH0_MOBILE_REDIRECT_URIS: "https://example.test/callback",
    ACCOUNT_RUNTIME_SECRET: "too-short",
  }, "http://localhost:3000");
  assert.equal(result.ready, false);
  assert.equal(result.checks.find((item) => item.id === "mobile-callback")?.status, "missing");
  assert.equal(result.checks.find((item) => item.id === "account-runtime-secret")?.status, "missing");
});

test("env parser yorumları ve tırnakları secret değerlerini açmadan işler", () => {
  assert.deepEqual(parseEnvText(`
    # ignored
    AUTH0_GATEWAY_ENABLED=true
    AUTH0_WEB_CLIENT_ID="fixture-client"
    export AUTH0_DATABASE_CONNECTION='fixture-connection'
  `), {
    AUTH0_GATEWAY_ENABLED: "true",
    AUTH0_WEB_CLIENT_ID: "fixture-client",
    AUTH0_DATABASE_CONNECTION: "fixture-connection",
  });
});

test("Auth0 provisioning runbook'u en az yetki ve exact callback sınırını korur", async () => {
  const runbook = await readFile(
    new URL("../docs/auth0-live-provisioning.md", import.meta.url),
    "utf8",
  );
  assert.match(runbook, /Regular Web Applications/);
  assert.match(runbook, /http:\/\/localhost:3000\/api\/auth\/web\/callback/);
  assert.match(runbook, /http:\/\/localhost:3000\/account\/reauthentication\/callback/);
  assert.match(runbook, /read:users/);
  assert.match(runbook, /update:users/);
  assert.match(runbook, /delete:users/);
  assert.match(runbook, /read:device_credentials/);
  assert.match(runbook, /delete:device_credentials/);
  assert.match(runbook, /Client secret/i);
  assert.doesNotMatch(runbook, /AUTH0_WEB_CLIENT_SECRET\s*=\s*\S+/);
  assert.doesNotMatch(runbook, /AUTH0_MANAGEMENT_CLIENT_SECRET\s*=\s*\S+/);
  assert.doesNotMatch(runbook, /ACCOUNT_RUNTIME_SECRET\s*=\s*\S+/);
});
