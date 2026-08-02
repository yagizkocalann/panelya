import assert from "node:assert/strict";
import test from "node:test";
import { validateProductionDeploymentReadiness } from "../scripts/verify-production-deployment-readiness.mjs";

const readyConfig = {
  PUBLIC_SITE_ORIGIN: "https://panelya.example",
  STUDIO_SITE_ORIGIN: "https://studio.panelya.example",
  LOCAL_DUMMY_CATALOG: "false",
  MEDIA_DERIVATIVE_DISPATCH_MODE: "cloudflare_queue",
  RATE_LIMIT_MODE: "cloudflare_hybrid",
  QUALITY_TELEMETRY_MODE: "cloudflare_logs",
  AD_RUNTIME_MODE: "disabled",
  ADMIN_BOOTSTRAP_TOKEN: "fixture-bootstrap-token-at-least-32-characters",
  PUSH_DELIVERY_MODE: "disabled",
  NOTIFICATION_DELIVERY_MODE: "local_outbox",
  AUTH0_GATEWAY_ENABLED: "true",
  AUTH0_ISSUER: "https://tenant.example.auth0.com/",
  AUTH0_MOBILE_CLIENT_ID: "fixture_native_client",
  AUTH0_AUDIENCE: "https://api.example.test",
  AUTH0_MOBILE_REDIRECT_URIS: "panelya://auth/callback",
  AUTH0_WEB_CLIENT_ID: "fixture_web_client",
  AUTH0_WEB_CLIENT_SECRET: "fixture_web_secret",
  AUTH0_WEB_REDIRECT_URIS: [
    "https://panelya.example/api/auth/web/callback",
    "https://panelya.example/account/reauthentication/callback",
  ].join(","),
  AUTH0_WEB_LOGOUT_URIS: "https://panelya.example",
  AUTH0_MANAGEMENT_CLIENT_ID: "fixture_management_client",
  AUTH0_MANAGEMENT_CLIENT_SECRET: "fixture_management_secret",
  AUTH0_MANAGEMENT_AUDIENCE: "https://tenant.example.auth0.com/api/v2/",
  AUTH0_DATABASE_CONNECTION: "Username-Password-Authentication",
  ACCOUNT_RUNTIME_SECRET: "fixture-account-runtime-secret-at-least-32-characters",
};

test("production ön kontrolü exact host, production modları ve Auth0 sınırını kabul eder", () => {
  const result = validateProductionDeploymentReadiness(readyConfig);
  assert.equal(result.ready, true);
  assert.equal(result.manualCloudflareChecks.length, 5);
});

test("production ön kontrolü localhost, yanlış Studio hostu ve yerel modları reddeder", () => {
  const result = validateProductionDeploymentReadiness({
    ...readyConfig,
    PUBLIC_SITE_ORIGIN: "http://localhost:3000",
    STUDIO_SITE_ORIGIN: "https://admin.panelya.example",
    LOCAL_DUMMY_CATALOG: "true",
    MEDIA_DERIVATIVE_DISPATCH_MODE: "local_browser",
    RATE_LIMIT_MODE: "d1_strict",
  });
  assert.equal(result.ready, false);
  for (const id of ["public-origin", "studio-origin", "dummy-catalog-disabled", "media-mode", "rate-limit-mode"]) {
    assert.equal(result.checks.find((item) => item.id === id)?.status, "missing");
  }
});

test("production ön kontrolü eksik FCM yapılandırmasını reddeder ama bilinçli disabled modu kabul eder", () => {
  assert.equal(validateProductionDeploymentReadiness(readyConfig).ready, true);
  const result = validateProductionDeploymentReadiness({
    ...readyConfig,
    PUSH_DELIVERY_MODE: "fcm",
    FCM_PROJECT_ID: "fixture-project",
    FCM_CLIENT_EMAIL: "",
    FCM_PRIVATE_KEY: "",
  });
  assert.equal(result.ready, false);
  assert.equal(result.checks.find((item) => item.id === "push-mode")?.status, "missing");
});

test("production ön kontrolü secret değerlerini sonuç nesnesine taşımaz", () => {
  const resultText = JSON.stringify(validateProductionDeploymentReadiness(readyConfig));
  assert.doesNotMatch(resultText, /fixture_web_secret|fixture_management_secret|fixture-bootstrap-token/u);
});
