import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { validateMobileAccountLiveReadiness } from "../scripts/verify-mobile-account-live-readiness.mjs";

const readyConfig = {
  AUTH0_GATEWAY_ENABLED: "true",
  AUTH0_ISSUER: "https://tenant.example.auth0.com/",
  AUTH0_MOBILE_CLIENT_ID: "fixture_native_client",
  AUTH0_AUDIENCE: "https://api.example.test",
  AUTH0_MOBILE_REDIRECT_URIS: "panelya://auth/callback",
  ACCOUNT_RUNTIME_SECRET: "fixture-account-runtime-secret-at-least-32-characters",
  AUTH0_MANAGEMENT_CLIENT_ID: "fixture_management_client",
  AUTH0_MANAGEMENT_CLIENT_SECRET: "fixture_management_secret",
  AUTH0_MANAGEMENT_AUDIENCE: "https://tenant.example.auth0.com/api/v2/",
  AUTH0_DATABASE_CONNECTION: "Username-Password-Authentication",
};

test("mobil hesap ön kontrolü tam yapılandırmayı hazır sayar", () => {
  const result = validateMobileAccountLiveReadiness(readyConfig);
  assert.equal(result.ready, true);
  assert.deepEqual(result.missingEnvVars, []);
});

test("mobil hesap ön kontrolü web-only alanları hiç istemez", () => {
  // Bu kontrol yalnız mobil akışın ihtiyaç duyduğu alanları denetler;
  // web BFF'e özgü confidential client/callback/logout alanları olmadan
  // da tam olarak 10 kontrolün tümü ready dönebilmeli.
  const result = validateMobileAccountLiveReadiness(readyConfig);
  assert.equal(result.checks.length, 10);
  assert.ok(!result.checks.some((item) => item.envVar.startsWith("AUTH0_WEB_")));
});

test("mobil hesap ön kontrolü boş yapılandırmada eksik değişken adlarını (değersiz) raporlar", () => {
  const result = validateMobileAccountLiveReadiness({});
  assert.equal(result.ready, false);
  assert.deepEqual(result.missingEnvVars.sort(), [
    "ACCOUNT_RUNTIME_SECRET",
    "AUTH0_AUDIENCE",
    "AUTH0_DATABASE_CONNECTION",
    "AUTH0_GATEWAY_ENABLED",
    "AUTH0_ISSUER",
    "AUTH0_MANAGEMENT_AUDIENCE",
    "AUTH0_MANAGEMENT_CLIENT_ID",
    "AUTH0_MANAGEMENT_CLIENT_SECRET",
    "AUTH0_MOBILE_CLIENT_ID",
    "AUTH0_MOBILE_REDIRECT_URIS",
  ]);
  for (const item of result.checks) {
    assert.ok(!JSON.stringify(item).includes("fixture"), "kontrol çıktısı gerçek değer taşımamalı");
  }
});

test("mobil hesap ön kontrolü kısa runtime secret'ı ve yanlış mobile callback'i reddeder", () => {
  const result = validateMobileAccountLiveReadiness({
    ...readyConfig,
    ACCOUNT_RUNTIME_SECRET: "too-short",
    AUTH0_MOBILE_REDIRECT_URIS: "https://example.test/callback",
  });
  assert.equal(result.ready, false);
  assert.ok(result.missingEnvVars.includes("ACCOUNT_RUNTIME_SECRET"));
  assert.ok(result.missingEnvVars.includes("AUTH0_MOBILE_REDIRECT_URIS"));
});

test("mobil hesap ön kontrolü .dev.vars eksikken tüm alanları dış kapı olarak işaretler ve secret yazdırmaz", async () => {
  const { execFile } = await import("node:child_process");
  const { promisify } = await import("node:util");
  const run = promisify(execFile);
  const missingEnvFile = fileURLToPath(
    new URL("./fixtures/does-not-exist.dev.vars", import.meta.url),
  );
  const { stdout } = await run(process.execPath, [
    fileURLToPath(
      new URL("../scripts/verify-mobile-account-live-readiness.mjs", import.meta.url),
    ),
    "--dev-vars",
    missingEnvFile,
  ]).catch((error) => ({ stdout: error.stdout }));
  assert.match(stdout, /bulunamadı/);
  assert.match(stdout, /ACCOUNT_RUNTIME_SECRET/);
  // Çıktı yalnız değişken ADLARI ve statik açıklama taşımalı, hiçbir
  // gerçek/sentetik değer içermemeli (bu test hiç değer sağlamıyor,
  // dolayısıyla "=" işaretinden sonra bir değer görünmesi beklenmez).
  assert.doesNotMatch(stdout, /=\S/);
});
