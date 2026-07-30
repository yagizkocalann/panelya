import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const workerUrl = new URL("../dist/server/index.js", import.meta.url);
workerUrl.searchParams.set("account-runtime-test", `${process.pid}-${Date.now()}`);
const { default: worker } = await import(workerUrl.href);

const executionContext = {
  waitUntil() {},
  passThroughOnException() {},
};

function request(path, init = {}) {
  return worker.fetch(
    new Request(`http://localhost${path}`, {
      ...init,
      headers: { accept: "application/json", ...init.headers },
    }),
    { ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) } },
    executionContext,
  );
}

test("ortak hesap uçları kimliksiz isteği fail-closed reddeder", async () => {
  for (const [path, init] of [
    ["/api/account", {}],
    ["/api/account/sessions", {}],
    ["/api/account/blocks", {}],
    ["/api/account/deletion", {}],
    ["/api/account/profile", {
      method: "PATCH",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ displayName: "Test Kullanıcısı" }),
    }],
  ]) {
    const response = await request(path, init);
    assert.equal(response.status, 401, path);
    assert.match(response.headers.get("cache-control") ?? "", /no-store/);
    assert.deepEqual(await response.json(), {
      schemaVersion: "1.0",
      error: "not_authenticated",
      errorDescription: "Bu işlem için giriş yapmalısın.",
      reauthenticate: true,
    });
  }
});

test("reauthentication kanıtı PKCE, OIDC ve tek-kullanım sınırlarını birlikte uygular", async () => {
  const [runtime, schema, migration] = await Promise.all([
    readFile(new URL("../app/lib/account-reauthentication.ts", import.meta.url), "utf8"),
    readFile(new URL("../db/schema.ts", import.meta.url), "utf8"),
    readFile(new URL("../drizzle/0017_dear_morg.sql", import.meta.url), "utf8"),
  ]);
  assert.match(runtime, /code_challenge_method", "S256"/);
  assert.match(runtime, /searchParams\.set\("max_age", "0"\)/);
  assert.match(runtime, /searchParams\.set\("prompt", "login"\)/);
  assert.match(runtime, /searchParams\.set\("scope", "openid profile email"\)/);
  assert.doesNotMatch(runtime, /searchParams\.set\("scope",[^)]*offline_access/);
  assert.match(runtime, /payload\.auth_time/);
  assert.match(runtime, /payload\.nonce/);
  assert.match(runtime, /compactDecrypt/);
  assert.match(runtime, /CompactEncrypt/);
  assert.match(runtime, /used_at IS NULL AND expires_at > \?/);
  assert.match(schema, /accountReauthenticationRequests/);
  assert.match(schema, /accountReauthenticationTokens/);
  assert.doesNotMatch(schema, /providerSubject: text|provider_subject/);
  assert.match(migration, /account_reauthentication_requests/);
  assert.match(migration, /account_reauthentication_tokens/);
});

test("hesap silme sagası kimliği silmeden önce hesabı kapatır ve kişisel alanları temizler", async () => {
  const [source, route] = await Promise.all([
    readFile(new URL("../app/lib/account-deletion.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/account/deletion/route.ts", import.meta.url), "utf8"),
  ]);
  assert.ok(source.indexOf("status = 'deletion_pending'") < source.indexOf("await deleteAuth0User"));
  assert.match(source, /DELETE FROM sessions WHERE user_id = \?/);
  assert.match(source, /DELETE FROM provider_identities WHERE user_id = \?/);
  assert.match(source, /display_name = 'Silinmiş hesap'/);
  assert.match(source, /status = 'deleted'/);
  assert.match(source, /UPDATE audit_events SET user_id = NULL/);
  assert.doesNotMatch(source, /provider\.subject[^)]*writeAudit|subject:\s*provider\.subject/);
  assert.match(route, /request\.headers\.get\("idempotency-key"\)/);
  assert.match(source, /idempotency_key_hash/);
  assert.match(source, /existing\.status !== "failed"/);
});

test("account actor cookie ve Bearer taşımalarını tek ortak sınıra dönüştürür", async () => {
  const [accountRuntime, auth0Runtime] = await Promise.all([
    readFile(new URL("../app/lib/account-runtime.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/auth0-runtime.ts", import.meta.url), "utf8"),
  ]);
  assert.match(accountRuntime, /identityFromBearerToken/);
  assert.match(accountRuntime, /getCurrentUser/);
  assert.match(accountRuntime, /transport: "mobile"/);
  assert.match(accountRuntime, /transport: "web"/);
  assert.match(auth0Runtime, /issuedAt < identity\.sessionsValidAfter/);
  assert.match(auth0Runtime, /identity\.status !== "active"/);
});

test("oturum toplu iptali mevcut native cihaz eşlenmeden başarılı görünmez", async () => {
  const source = await readFile(new URL("../app/lib/account-sessions.ts", import.meta.url), "utf8");
  assert.match(source, /scope === "others" && actor\.transport === "mobile"/);
  assert.match(source, /actor\.issuer && !native/);
  assert.match(source, /scope === "all" \|\| actor\.transport === "web"/);
});

test("management hataları ortak hesap hata kodlarına çevrilir", async () => {
  const source = await readFile(new URL("../app/lib/auth0-management.ts", import.meta.url), "utf8");
  assert.match(source, /AccountRuntimeError\("not_found"/);
  assert.match(source, /status === 400 \|\| status === 409/);
  assert.match(source, /AccountRuntimeError\("conflict"/);
  assert.doesNotMatch(source, /!clientSecret\.trim\(\) \|\| !databaseConnection\.trim\(\)/);
  assert.match(source, /if \(!config\.databaseConnection\)/);
  assert.match(source, /\["refresh_token", "rotating_refresh_token"\]/);
  assert.match(source, /new Map\(values\.flat\(\)/);
});

test("yerel QA şifre yenilemesi Auth0 management yapılandırmasına yönelmez", async () => {
  const source = await readFile(new URL("../app/api/account/password-reset/route.ts", import.meta.url), "utf8");
  assert.match(source, /actor\.issuer && gateway && management/);
  assert.match(source, /else if \(!actor\.issuer\)/);
});
