import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import test from "node:test";
import Ajv2020 from "ajv/dist/2020.js";

const contractUrl = new URL("../packages/contracts/schema.json", import.meta.url);
const contract = JSON.parse(await readFile(contractUrl, "utf8"));
const ajv = new Ajv2020({ allErrors: true, strict: true });
ajv.addSchema(contract);

function validator(definition) {
  return ajv.compile({ $ref: `${contract.$id}#/$defs/${definition}` });
}

function assertContract(validate, value, label) {
  assert.equal(
    validate(value),
    true,
    `${label} sözleşme dışına çıktı:\n${JSON.stringify(validate.errors, null, 2)}`,
  );
}

const validators = {
  catalog: validator("CatalogResponse"),
  discovery: validator("DiscoveryResponse"),
  series: validator("SeriesDetailResponse"),
  manifest: validator("EpisodeManifestResponse"),
  error: validator("ErrorResponse"),
  authConfig: validator("AuthProviderConfigResponse"),
  authCodeExchange: validator("AuthAuthorizationCodeExchangeRequest"),
  authRefresh: validator("AuthRefreshTokenRequest"),
  authRevoke: validator("AuthRevokeRequest"),
  authToken: validator("AuthTokenResponse"),
  authState: validator("AuthStateResponse"),
  authError: validator("AuthErrorResponse"),
  authLogout: validator("AuthLogoutResponse"),
  accountOverview: validator("AccountOverviewResponse"),
  accountProfileUpdate: validator("AccountProfileUpdateRequest"),
  accountPasswordReset: validator("AccountPasswordResetRequest"),
  accountEmailChange: validator("AccountEmailChangeRequest"),
  accountActionAccepted: validator("AccountActionAcceptedResponse"),
  accountReauthStartRequest: validator("AccountReauthenticationStartRequest"),
  accountReauthStartResponse: validator("AccountReauthenticationStartResponse"),
  accountReauthCompleteRequest: validator("AccountReauthenticationCompleteRequest"),
  accountReauthCompleteResponse: validator("AccountReauthenticationCompleteResponse"),
  accountSessions: validator("AccountSessionsResponse"),
  accountSessionRevocationRequest: validator("AccountSessionRevocationRequest"),
  accountSessionRevocationResponse: validator("AccountSessionRevocationResponse"),
  blockedAccounts: validator("BlockedAccountsResponse"),
  accountDeletionSummary: validator("AccountDeletionSummaryResponse"),
  accountDeletionRequest: validator("AccountDeletionRequest"),
  accountDeletionOperation: validator("AccountDeletionOperationResponse"),
  accountError: validator("AccountErrorResponse"),
  library: validator("LibraryResponse"),
  libraryUpsert: validator("LibraryUpsertRequest"),
  libraryMutation: validator("LibraryMutationResponse"),
  libraryRemoval: validator("LibraryRemovalResponse"),
  libraryError: validator("LibraryErrorResponse"),
};

const fixtureCases = [
  ["catalog.v1.json", validators.catalog],
  ["discovery.v1.json", validators.discovery],
  ["series-detail.v1.json", validators.series],
  ["episode-manifest.v1.json", validators.manifest],
  ["auth-config.v1.json", validators.authConfig],
  ["auth-code-exchange-request.v1.json", validators.authCodeExchange],
  ["auth-refresh-request.v1.json", validators.authRefresh],
  ["auth-revoke-request.v1.json", validators.authRevoke],
  ["auth-token.v1.json", validators.authToken],
  ["auth-state-authenticated.v1.json", validators.authState],
  ["auth-state-anonymous.v1.json", validators.authState],
  ["auth-error.v1.json", validators.authError],
  ["auth-logout.v1.json", validators.authLogout],
  ["account-overview-database.v1.json", validators.accountOverview],
  ["account-overview-google.v1.json", validators.accountOverview],
  ["account-profile-update-request.v1.json", validators.accountProfileUpdate],
  ["account-password-reset-request.v1.json", validators.accountPasswordReset],
  ["account-email-change-request.v1.json", validators.accountEmailChange],
  ["account-action-accepted.v1.json", validators.accountActionAccepted],
  ["account-reauthentication-start-request.v1.json", validators.accountReauthStartRequest],
  ["account-reauthentication-start-response.v1.json", validators.accountReauthStartResponse],
  ["account-reauthentication-complete-request.v1.json", validators.accountReauthCompleteRequest],
  ["account-reauthentication-complete-response.v1.json", validators.accountReauthCompleteResponse],
  ["account-sessions.v1.json", validators.accountSessions],
  ["account-session-revocation-request.v1.json", validators.accountSessionRevocationRequest],
  ["account-session-revocation-response.v1.json", validators.accountSessionRevocationResponse],
  ["account-blocks.v1.json", validators.blockedAccounts],
  ["account-deletion-summary.v1.json", validators.accountDeletionSummary],
  ["account-deletion-request.v1.json", validators.accountDeletionRequest],
  ["account-deletion-response.v1.json", validators.accountDeletionOperation],
  ["account-error.v1.json", validators.accountError],
  ["library-response.v1.json", validators.library],
  ["library-upsert-request.v1.json", validators.libraryUpsert],
  ["library-mutation-response.v1.json", validators.libraryMutation],
  ["library-removal-response.v1.json", validators.libraryRemoval],
  ["library-error.v1.json", validators.libraryError],
];

test("OpenAPI path'leri mevcut JSON Schema tanımlarına bağlanır", async () => {
  const openapi = JSON.parse(
    await readFile(new URL("../packages/contracts/openapi.json", import.meta.url), "utf8"),
  );
  assert.equal(openapi.openapi, "3.1.0");
  assert.deepEqual(
    Object.keys(openapi.paths).sort(),
    [
      "/api/account",
      "/api/account/blocks",
      "/api/account/blocks/{userId}",
      "/api/account/deletion",
      "/api/account/email-change",
      "/api/account/password-reset",
      "/api/account/profile",
      "/api/account/reauthentication/complete",
      "/api/account/reauthentication/start",
      "/api/account/sessions",
      "/api/account/sessions/revoke",
      "/api/account/sessions/{sessionId}",
      "/api/auth/config",
      "/api/auth/me",
      "/api/auth/mobile/revoke",
      "/api/auth/mobile/token",
      "/api/catalog",
      "/api/discovery",
      "/api/library",
      "/api/library/{slug}",
      "/api/series/{slug}",
      "/api/series/{slug}/episodes/{episodeSlug}",
    ],
  );
  assert.equal(openapi.info.version, "1.5.0");
  assert.deepEqual(contract.$defs.AccountPasswordResetRequest.properties, {});
  assert.deepEqual(
    contract.$defs.AccountSessionPlatform.enum,
    ["web", "android", "ios", "unspecified"],
  );

  const refs = JSON.stringify(openapi).match(/\.\/schema\.json#\/\$defs\/[A-Za-z]+/g) ?? [];
  assert.ok(refs.length >= 5, "OpenAPI response'ları ortak schema tanımlarına bağlanmalı");
  for (const ref of refs) {
    const definition = ref.split("/").at(-1);
    assert.ok(contract.$defs[definition], `${ref} mevcut bir tanıma işaret etmeli`);
  }
  assert.equal(openapi.components.securitySchemes.PanelyaAccessToken.scheme, "bearer");
  assert.equal(openapi.components.securitySchemes.PanelyaWebSession.in, "cookie");
  for (const [path, item] of Object.entries(openapi.paths)) {
    if (!path.startsWith("/api/account") && !path.startsWith("/api/library")) continue;
    for (const operation of Object.values(item)) {
      assert.deepEqual(
        operation.security,
        [{ PanelyaAccessToken: [] }, { PanelyaWebSession: [] }],
        `${path} yalniz mobil Bearer veya web host-only session kabul etmeli`,
      );
    }
  }
});

test("kütüphane fixture'ları tam durum, public metadata ve stabil sıra taşır", async () => {
  const [library, request, mutation, removal] = await Promise.all([
    readFile(new URL("../packages/contracts/fixtures/library-response.v1.json", import.meta.url), "utf8").then(JSON.parse),
    readFile(new URL("../packages/contracts/fixtures/library-upsert-request.v1.json", import.meta.url), "utf8").then(JSON.parse),
    readFile(new URL("../packages/contracts/fixtures/library-mutation-response.v1.json", import.meta.url), "utf8").then(JSON.parse),
    readFile(new URL("../packages/contracts/fixtures/library-removal-response.v1.json", import.meta.url), "utf8").then(JSON.parse),
  ]);
  assert.deepEqual(Object.keys(request).sort(), ["favorite", "status"]);
  assert.equal(typeof request.favorite, "boolean");
  assert.equal(mutation.item.series.slug, library.items[0].series.slug);
  assert.equal(removal.removed, true);
  assert.ok(library.items.every((item) => item.series.episodeCount >= 0));
  assert.ok(library.items.every((item) => !Object.hasOwn(item.series, "episodes")));
  assert.doesNotMatch(
    JSON.stringify({ library, mutation }),
    /storageKey|jobId|queue|providerSubject|accessToken|refreshToken/i,
  );
});

test("paylaşılan fixture'lar JSON Schema sözleşmesine uyar", async () => {
  for (const [filename, validate] of fixtureCases) {
    const fixture = JSON.parse(
      await readFile(new URL(`../packages/contracts/fixtures/${filename}`, import.meta.url), "utf8"),
    );
    assertContract(validate, fixture, filename);
  }
});

test("responsive medya fixture'lari yalniz hazir public varyantlari tasir", async () => {
  const [catalog, manifest] = await Promise.all([
    readFile(new URL("../packages/contracts/fixtures/catalog.v1.json", import.meta.url), "utf8").then(JSON.parse),
    readFile(new URL("../packages/contracts/fixtures/episode-manifest.v1.json", import.meta.url), "utf8").then(JSON.parse),
  ]);
  const coverVariants = catalog.series[0].coverImageVariants;
  const panelVariants = manifest.episode.panels[0].image.variants;
  for (const variants of [coverVariants, panelVariants]) {
    assert.ok(Array.isArray(variants) && variants.length > 0);
    assert.deepEqual(variants.map((variant) => variant.width), [...variants].map((variant) => variant.width).sort((a, b) => a - b));
    assert.ok(variants.every((variant) => variant.mimeType === "image/webp"));
    assert.ok(variants.every((variant) => /^\/api\/media\/[A-Za-z0-9_-]+\?width=\d+$/.test(variant.src)));
    assert.ok(variants.every((variant) => !("storageKey" in variant) && !("jobId" in variant)));
  }
});

test("production auth fixture'lari secret veya gecerli token tasimaz", async () => {
  const [config, token, error] = await Promise.all([
    readFile(new URL("../packages/contracts/fixtures/auth-config.v1.json", import.meta.url), "utf8").then(JSON.parse),
    readFile(new URL("../packages/contracts/fixtures/auth-token.v1.json", import.meta.url), "utf8").then(JSON.parse),
    readFile(new URL("../packages/contracts/fixtures/auth-error.v1.json", import.meta.url), "utf8").then(JSON.parse),
  ]);
  assert.equal(config.provider, "auth0");
  assert.equal(config.flow, "authorization_code_pkce");
  assert.equal(config.refreshTokenRotation, true);
  assert.ok(config.scopes.includes("offline_access"));
  assert.ok(config.issuer.endsWith(".example/"));
  assert.doesNotMatch(JSON.stringify(config), /clientSecret|privateKey|managementToken/i);
  assert.match(token.accessToken, /^fixture_/);
  assert.match(token.refreshToken, /^fixture_/);
  assert.equal(error.reauthenticate, true);
});

test("auth state kapali, kosullu ve Dart codegen ile yapisal olarak uyumludur", () => {
  const authState = contract.$defs.AuthStateResponse;
  assert.equal(authState.type, "object");
  assert.equal(authState.additionalProperties, false);
  assert.equal("allOf" in authState, false, "kosul yapisal allOf birlesimi gibi modellenmemeli");
  assert.ok(authState.if && authState.then && authState.else);

  assert.equal(
    validators.authState({ schemaVersion: "1.0", authenticated: true, user: null }),
    false,
    "authenticated=true iken user zorunlu olmali",
  );
  assert.equal(
    validators.authState({
      schemaVersion: "1.0",
      authenticated: false,
      user: {
        id: "user_fixture_01",
        displayName: "Deniz Kaya",
        email: "deniz@example.test",
        emailVerified: true,
        role: "reader",
      },
    }),
    false,
    "authenticated=false iken user null olmali",
  );
});

test("hesap sozlesmesi server capability ve tek kullanimlik reauthentication sinirini korur", async () => {
  const [database, google, start, complete, deletion, sessions] = await Promise.all([
    readFile(new URL("../packages/contracts/fixtures/account-overview-database.v1.json", import.meta.url), "utf8").then(JSON.parse),
    readFile(new URL("../packages/contracts/fixtures/account-overview-google.v1.json", import.meta.url), "utf8").then(JSON.parse),
    readFile(new URL("../packages/contracts/fixtures/account-reauthentication-start-request.v1.json", import.meta.url), "utf8").then(JSON.parse),
    readFile(new URL("../packages/contracts/fixtures/account-reauthentication-complete-response.v1.json", import.meta.url), "utf8").then(JSON.parse),
    readFile(new URL("../packages/contracts/fixtures/account-deletion-summary.v1.json", import.meta.url), "utf8").then(JSON.parse),
    readFile(new URL("../packages/contracts/fixtures/account-sessions.v1.json", import.meta.url), "utf8").then(JSON.parse),
  ]);

  assert.equal(database.capabilities.passwordAction, "enabled");
  assert.equal(database.capabilities.emailChange, "unavailable");
  assert.equal(google.capabilities.passwordAction, "provider_managed");
  assert.equal(google.capabilities.emailChange, "unavailable");
  assert.equal(start.codeChallengeMethod, "S256");
  assert.equal(complete.purpose, "account_deletion");
  assert.match(complete.reauthenticationToken, /^fixture_/);
  assert.ok(!("authorizationCode" in complete));
  assert.ok(deletion.deleted.includes("auth_identity"));
  assert.ok(deletion.anonymized.includes("community_contributions"));
  assert.ok(deletion.retained.includes("legal_and_audit_records"));
  assert.ok(sessions.sessions.every((session) => !("ip" in session)));
  assert.doesNotMatch(
    JSON.stringify({ database, google, start, complete, deletion, sessions }),
    /clientSecret|refreshToken|providerSubject|managementToken|storageKey/i,
  );

  const fixtureDirectory = new URL("../packages/contracts/fixtures/", import.meta.url);
  const accountFixtureNames = (await readdir(fixtureDirectory))
    .filter((name) => name.startsWith("account-"));
  assert.equal(accountFixtureNames.length, 18);
  const allAccountFixtures = await Promise.all(
    accountFixtureNames.map((name) =>
      readFile(new URL(name, fixtureDirectory), "utf8").then(JSON.parse),
    ),
  );
  const serialized = JSON.stringify(allAccountFixtures);
  assert.doesNotMatch(
    serialized,
    /"(?:clientSecret|privateKey|refreshToken|providerSubject|managementToken|password)"\s*:/i,
  );
  assert.doesNotMatch(serialized, /panelya-dev|auth0\.com/i);
});

const workerUrl = new URL("../dist/server/index.js", import.meta.url);
workerUrl.searchParams.set("contracts-test", `${process.pid}-${Date.now()}`);
const { default: worker } = await import(workerUrl.href);

function request(path) {
  return worker.fetch(
    new Request(`http://localhost${path}`, { headers: { accept: "application/json" } }),
    { ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) } },
    { waitUntil() {}, passThroughOnException() {} },
  );
}

test("derlenmiş Worker public API cevapları ortak sözleşmeye uyar", async () => {
  const catalogResponse = await request("/api/catalog");
  assert.equal(catalogResponse.status, 200);
  const catalog = await catalogResponse.json();
  assertContract(validators.catalog, catalog, "GET /api/catalog");

  assert.ok(catalog.series.length > 0, "fixture/seed kataloğunda en az bir yayınlanmış seri olmalı");

  const discoveryResponse = await request("/api/discovery");
  assert.equal(discoveryResponse.status, 200);
  const discovery = await discoveryResponse.json();
  assertContract(validators.discovery, discovery, "GET /api/discovery");
  assert.equal(discovery.featuredSeries?.slug, catalog.featuredSlug);
  assert.ok(discovery.genres.length > 0);
  assert.ok(discovery.latestEpisodes.length > 0);
  assert.ok(discovery.latestEpisodes.length <= 100);
  assert.ok(discovery.latestEpisodes.every((item) => !("panels" in item.episode)));
  assert.doesNotMatch(JSON.stringify(discovery), /publishedAtTimestamp|storageKey|jobId/);
  assert.match(discoveryResponse.headers.get("cache-control") ?? "", /max-age=60/);

  for (const catalogSeries of catalog.series) {
    const seriesResponse = await request(`/api/series/${catalogSeries.slug}`);
    assert.equal(seriesResponse.status, 200);
    const series = await seriesResponse.json();
    assertContract(validators.series, series, `GET /api/series/${catalogSeries.slug}`);
    assert.ok(series.episodes.length > 0, `${catalogSeries.slug} en az bir yayınlanmış bölüm taşımalı`);

    for (const episode of series.episodes) {
      const manifestResponse = await request(
        `/api/series/${catalogSeries.slug}/episodes/${episode.slug}`,
      );
      assert.equal(manifestResponse.status, 200);
      assertContract(
        validators.manifest,
        await manifestResponse.json(),
        `GET /api/series/${catalogSeries.slug}/episodes/${episode.slug}`,
      );
    }
  }
});

test("anonim auth/me cevabi ortak auth state sozlesmesine uyar", async () => {
  const response = await request("/api/auth/me");
  assert.equal(response.status, 200);
  const state = await response.json();
  assertContract(validators.authState, state, "GET /api/auth/me");
  assert.equal(state.authenticated, false);
  assert.equal(state.user, null);
  assert.match(response.headers.get("cache-control") ?? "", /no-store/);
});

test("anonim kütüphane API'si JSON hata sözleşmesiyle fail-closed kalır", async () => {
  for (const [path, method, body] of [
    ["/api/library", "GET", undefined],
    ["/api/library/gece-vardiyasi", "POST", JSON.stringify({ status: "reading", favorite: true })],
    ["/api/library/gece-vardiyasi", "DELETE", undefined],
  ]) {
    const response = await worker.fetch(
      new Request(`http://localhost${path}`, {
        method,
        headers: { accept: "application/json", ...(body ? { "content-type": "application/json" } : {}) },
        ...(body ? { body } : {}),
      }),
      { ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) } },
      { waitUntil() {}, passThroughOnException() {} },
    );
    assert.equal(response.status, 401, `${method} ${path} anonim isteği reddetmeli`);
    assertContract(validators.libraryError, await response.json(), `${method} ${path}`);
    assert.match(response.headers.get("cache-control") ?? "", /no-store/);
  }
});

test("production auth gateway yapilandirilmadan fail-closed kalir", async () => {
  for (const [path, method] of [
    ["/api/auth/config", "GET"],
    ["/api/auth/mobile/token", "POST"],
    ["/api/auth/mobile/revoke", "POST"],
  ]) {
    const response = await worker.fetch(
      new Request(`http://localhost${path}`, {
        method,
        headers: { accept: "application/json", "content-type": "application/json" },
      }),
      { ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) } },
      { waitUntil() {}, passThroughOnException() {} },
    );
    assert.equal(response.status, 503, `${method} ${path} fail-closed olmali`);
    assertContract(validators.authError, await response.json(), `${method} ${path}`);
    assert.match(response.headers.get("cache-control") ?? "", /no-store/);
  }
});

test("public API 404 cevapları ortak hata sözleşmesine uyar", async () => {
  const seriesResponse = await request("/api/series/olmayan-seri");
  assert.equal(seriesResponse.status, 404);
  assertContract(validators.error, await seriesResponse.json(), "series 404");

  const episodeResponse = await request("/api/series/olmayan-seri/episodes/olmayan-bolum");
  assert.equal(episodeResponse.status, 404);
  assertContract(validators.error, await episodeResponse.json(), "episode 404");
});
