import assert from "node:assert/strict";
import { readFile, stat } from "node:fs/promises";
import test from "node:test";

const workerUrl = new URL("../dist/server/index.js", import.meta.url);
workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
const { default: worker } = await import(workerUrl.href);

function request(path, accept = "text/html", origin = "http://localhost", init = {}) {
  return worker.fetch(
    new Request(`${origin}${path}`, { ...init, headers: { accept, ...init.headers } }),
    { ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) } },
    { waitUntil() {}, passThroughOnException() {} },
  );
}

test("ana sayfa özgün katalog ve doğru metadata ile render edilir", async () => {
  const response = await request("/");
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);
  const html = await response.text();
  assert.match(html, /<title>Panelya/);
  assert.match(html, /Gece Vardiyası/);
  assert.match(html, /Yeni bölüm eklenenler/);
  assert.match(html, /href="\/gece-vardiyasi\/bolum-1"/);
  assert.match(html, /data-ad-test-slot="home-feed-01"/);
  assert.doesNotMatch(html, /codex-preview|react-loading-skeleton|OkuToon/i);
});

test("D1 katalog keşfi normalize arama, filtre, sıralama ve keyset cursor sınırını korur", async () => {
  const [schema, database, repository, page, header, css, migration, manualQa] = await Promise.all([
    readFile(new URL("../db/schema.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/database.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/content-repository.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/components/SiteHeader.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/globals.css", import.meta.url), "utf8"),
    readFile(new URL("../drizzle/0012_round_mulholland_black.sql", import.meta.url), "utf8"),
    readFile(new URL("../docs/manual-qa-checklist.md", import.meta.url), "utf8"),
  ]);
  assert.match(schema, /searchText: text\("search_text"\)/);
  assert.match(schema, /content_series_discovery_updated_idx/);
  assert.match(database, /ALTER TABLE content_series ADD COLUMN search_text/);
  assert.match(migration, /ALTER TABLE `content_series` ADD `search_text`/);
  assert.match(repository, /normalizeCatalogSearch/);
  assert.match(repository, /searchPublishedSeries/);
  assert.match(repository, /WITH catalog AS/);
  assert.match(repository, /discovery_updated_at < \?/);
  assert.match(repository, /rating < \?/);
  assert.match(repository, /title > \? COLLATE NOCASE/);
  assert.match(repository, /LIMIT \?/);
  assert.match(repository, /decodeCatalogCursor/);
  assert.match(repository, /catalogCursorScope/);
  assert.match(repository, /cursorWasInvalid/);
  assert.match(page, /className="catalog-filter-form"/);
  assert.match(page, /Sonraki sonuçlar/);
  assert.match(header, /listPublishedGenres/);
  assert.match(css, /\.catalog-filter-form[^}]*grid-template-columns/);
  assert.match(manualQa, /QA-CAT-01/);

  const catalogHtml = await (await request("/?view=catalog&q=ses&sort=title")).text();
  assert.match(catalogHtml, /class="catalog-filter-form"/);
  assert.match(catalogHtml, /name="q"[^>]*value="ses"/);
  assert.match(catalogHtml, /option value="title" selected/);
  assert.match(catalogHtml, /Yarınki Ses/);
  const invalidCursorHtml = await (await request("/?view=catalog&cursor=bozuk")).text();
  assert.match(invalidCursorHtml, /Geçersiz veya eski sayfa bağlantısı/);

  const catalogApi = await (await request("/api/catalog", "application/json")).json();
  assert.deepEqual(Object.keys(catalogApi).sort(), ["featuredSlug", "schemaVersion", "series"]);
});

test("seri sayfası ve okuyucu route'ları sunucuda render edilir", async () => {
  const seriesResponse = await request("/gece-vardiyasi");
  assert.equal(seriesResponse.status, 200);
  const seriesHtml = await seriesResponse.text();
  assert.match(seriesHtml, /Bölümler/);
  assert.match(seriesHtml, /Kayıp Dakika/);
  assert.match(seriesHtml, /Kaldığın yer bu cihazda seni bekler/);
  assert.match(seriesHtml, /action="\/api\/library\/gece-vardiyasi"/);
  assert.match(seriesHtml, /data-ad-test-slot="series-detail-01"/);
  assert.match(seriesHtml, /Puanlar ve yorumlar/);
  assert.match(seriesHtml, /href="\/login\?return_to=/);

  const episodeResponse = await request("/gece-vardiyasi/bolum-1");
  assert.equal(episodeResponse.status, 200);
  const episodeHtml = await episodeResponse.text();
  assert.match(episodeHtml, /Son Teslimat/);
  assert.match(episodeHtml, /Bu bölüm burada bitti/);
  assert.match(episodeHtml, /name="robots" content="noindex, follow"/i);
});

test("canonical, robots, sitemap ve ComicSeries JSON-LD ayni public origin politikasini kullanir", async () => {
  const jsonLdComponent = await readFile(new URL("../app/components/JsonLd.tsx", import.meta.url), "utf8");
  assert.match(jsonLdComponent, /JSON\.stringify\(data\)\.replace\(\/<\/g, "\\\\u003c"\)/);
  const homeHtml = await (await request("/")).text();
  assert.match(homeHtml, /<link rel="canonical" href="http:\/\/localhost:3000\/"/i);

  const seriesHtml = await (await request("/gece-vardiyasi")).text();
  assert.match(seriesHtml, /<link rel="canonical" href="http:\/\/localhost:3000\/gece-vardiyasi"/i);
  const jsonLdMatch = seriesHtml.match(/<script type="application\/ld\+json">(.+?)<\/script>/);
  assert.ok(jsonLdMatch, "Seri sayfasi JSON-LD script'i icermeli");
  const jsonLd = JSON.parse(jsonLdMatch[1]);
  assert.equal(jsonLd["@type"], "ComicSeries");
  assert.equal(jsonLd.url, "http://localhost:3000/gece-vardiyasi");
  assert.equal(jsonLd.publisher.name, "Panelya");
  assert.ok(Array.isArray(jsonLd.hasPart) && jsonLd.hasPart.length > 0);
  assert.ok(jsonLd.hasPart.every((episode) => episode["@type"] === "ComicIssue"));

  const episodeHtml = await (await request("/gece-vardiyasi/bolum-1")).text();
  assert.match(episodeHtml, /<link rel="canonical" href="http:\/\/localhost:3000\/gece-vardiyasi\/bolum-1"/i);
  assert.match(episodeHtml, /name="robots" content="noindex, follow"/i);

  const robotsResponse = await request("/robots.txt", "text/plain");
  assert.equal(robotsResponse.status, 200);
  const robots = await robotsResponse.text();
  assert.match(robots, /Allow: \//);
  assert.match(robots, /Disallow: \/api\//);
  assert.match(robots, /Disallow: \/preview\//);
  assert.match(robots, /Sitemap: http:\/\/localhost:3000\/sitemap\.xml/);

  const studioRobots = await (await request("/robots.txt", "text/plain", "http://studio.localhost")).text();
  assert.match(studioRobots, /^User-agent: \*\s+Disallow: \/\s*$/i);
  assert.doesNotMatch(studioRobots, /Sitemap:/i);

  const sitemapResponse = await request("/sitemap.xml", "application/xml");
  assert.equal(sitemapResponse.status, 200);
  const sitemap = await sitemapResponse.text();
  assert.match(sitemap, /<loc>http:\/\/localhost:3000\/gece-vardiyasi<\/loc>/);
  assert.match(sitemap, /<loc>http:\/\/localhost:3000\/publishing-principles<\/loc>/);
  assert.doesNotMatch(sitemap, /\/gece-vardiyasi\/bolum-1|\/api\/|\/preview\/|studio\.localhost/);
});

test("görsel pilot katalog, seri ve okuyucu rotalarına bağlıdır", async () => {
  const home = await (await request("/")).text();
  assert.match(home, /href="\/bir-bilet-uzaginda"/);

  const seriesResponse = await request("/bir-bilet-uzaginda");
  assert.equal(seriesResponse.status, 200);
  const seriesHtml = await seriesResponse.text();
  assert.match(seriesHtml, /Bir Bilet Uzağında/);
  assert.match(seriesHtml, /Görsel Pilot/);
  assert.match(seriesHtml, /href="\/bir-bilet-uzaginda\/bolum-1"/);

  const episodeResponse = await request("/bir-bilet-uzaginda/bolum-1");
  assert.equal(episodeResponse.status, 200);
  const episodeHtml = await episodeResponse.text();
  assert.match(episodeHtml, /Rüzgâra Karışan/);
  assert.match(episodeHtml, /src="\/images\/bir-bilet-uzaginda-bolum-1\.webp"/);
  assert.match(episodeHtml, /story-image-panel/);

  const manifestResponse = await request("/api/series/bir-bilet-uzaginda/episodes/bolum-1", "application/json");
  assert.equal(manifestResponse.status, 200);
  const manifest = await manifestResponse.json();
  assert.equal(manifest.episode.panels[0].image.width, 864);
  assert.equal(manifest.episode.panels[0].image.height, 1821);
});

test("Yarınki Ses özgün pilotu 18 sıralı panel ve ayrı lettering katmanıyla yayınlanır", async () => {
  const productionManifest = JSON.parse(await readFile(new URL("../artifacts/yarinki-ses/manifest.json", import.meta.url), "utf8"));
  assert.equal(productionManifest.qaScore, 93);
  assert.equal(productionManifest.panels.length, 18);
  assert.equal(new Set(productionManifest.panels.map((panel) => panel.position)).size, 18);
  await Promise.all(productionManifest.panels.map(async (panel) => {
    const filename = panel.file.split("/").at(-1);
    const info = await stat(new URL(`../public/images/yarinki-ses/${filename}`, import.meta.url));
    assert.match(filename, /\.webp$/);
    assert.ok(info.size > 15_000, `${filename} optimize edilmiş gerçek bir panel dosyası olmalı`);
  }));

  const seriesResponse = await request("/yarinki-ses");
  assert.equal(seriesResponse.status, 200);
  const seriesHtml = await seriesResponse.text();
  assert.match(seriesHtml, /Kayıtta Ben Varım/);
  assert.match(seriesHtml, /href="\/yarinki-ses\/bolum-1"/);

  const episodeResponse = await request("/yarinki-ses/bolum-1");
  assert.equal(episodeResponse.status, 200);
  const episodeHtml = await episodeResponse.text();
  assert.equal((episodeHtml.match(/class="story-image-panel"/g) ?? []).length, 18);
  assert.match(episodeHtml, /story-image-lettering/);
  assert.match(episodeHtml, /Baran… bu kez gelme/);
  assert.match(episodeHtml, /panel-018-mode-e-v1-clean\.webp/);

  const apiResponse = await request("/api/series/yarinki-ses/episodes/bolum-1", "application/json");
  assert.equal(apiResponse.status, 200);
  const apiManifest = await apiResponse.json();
  assert.equal(apiManifest.episode.panels.length, 18);
});

test("katalog API'si mobil istemciye uygun sürümlü JSON döndürür", async () => {
  const response = await request("/api/catalog", "application/json");
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^application\/json\b/i);
  const data = await response.json();
  assert.equal(data.schemaVersion, "1.0");
  assert.equal(data.featuredSlug, "gece-vardiyasi");
  assert.ok(data.series.length >= 6);
  assert.equal(data.series[0].episodeCount, 3);

  const seriesResponse = await request("/api/series/gece-vardiyasi", "application/json");
  assert.equal(seriesResponse.status, 200);
  const series = await seriesResponse.json();
  assert.equal(series.schemaVersion, "1.0");
  assert.equal(series.series.slug, "gece-vardiyasi");
  assert.equal(series.episodes[0].panelCount, 2);

  const manifestResponse = await request("/api/series/gece-vardiyasi/episodes/bolum-1", "application/json");
  assert.equal(manifestResponse.status, 200);
  const manifest = await manifestResponse.json();
  assert.equal(manifest.episode.panels.length, 7);
  assert.equal(manifest.navigation.previous, null);
  assert.equal(manifest.navigation.next.slug, "bolum-2");
});

test("bilinmeyen seri 404 döndürür", async () => {
  const response = await request("/olmayan-seri");
  assert.equal(response.status, 404);
  const apiResponse = await request("/api/series/olmayan-seri", "application/json");
  assert.equal(apiResponse.status, 404);
});

test("kurumsal, iletişim ve yasal rotalar bağlıdır", async () => {
  for (const path of ["/about", "/creators", "/publishing-principles", "/production-journal", "/contact", "/privacy", "/terms", "/copyright"]) {
    const response = await request(path);
    assert.equal(response.status, 200, `${path} 200 dönmeli`);
  }
  const contact = await (await request("/contact?subject=creator")).text();
  assert.match(contact, /action="\/api\/contact"/);
  assert.match(contact, /option value="creator" selected/);
  const home = await (await request("/")).text();
  assert.match(home, /href="\/about"/);
  assert.match(home, /href="\/contact"/);
  assert.match(home, /href="\/privacy"/);
});

test("PC, tablet ve mobil responsive sözleşmesi korunur", async () => {
  const css = await readFile(new URL("../app/globals.css", import.meta.url), "utf8");
  assert.match(css, /@media \(max-width: 960px\)/);
  assert.match(css, /@media \(max-width: 720px\)/);
  assert.match(css, /@media \(max-width: 420px\)/);
  assert.match(css, /\.card-grid[^}]*grid-template-columns:\s*repeat\(4, 1fr\)/s);
  assert.match(css, /@media \(max-width: 960px\)[\s\S]*\.card-grid[^}]*repeat\(2, 1fr\)/);
  assert.match(css, /\.reader-tools button[^}]*width:\s*44px[^}]*height:\s*44px/);
  assert.match(css, /\.reader-dock a, \.reader-dock > span[^}]*min-width:\s*44px[^}]*min-height:\s*44px/);
  assert.match(css, /\.genre-strip a, \.genre-pills a[^}]*min-height:\s*44px/);
  assert.match(css, /\.catalog-filter-form input, \.catalog-filter-form select[^}]*min-height:\s*48px/);
});

test("yerel hesap, topluluk güvenliği, Studio ve Google reklam testi sözleşmesi kaynakta bulunur", async () => {
  const [schema, hosting, authActions, authControls, studio, library, adSlot, adLab, footer, notifications, resetPage, accountPage, moderationPage, proxy] = await Promise.all([
    readFile(new URL("../db/schema.ts", import.meta.url), "utf8"),
    readFile(new URL("../.openai/hosting.json", import.meta.url), "utf8"),
    readFile(new URL("../app/components/AuthActions.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/components/AuthPageControls.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/studio/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/library/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/components/AdTestSlot.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/studio/ads/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/components/SiteFooter.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/notifications.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/reset-password/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/account/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/studio/moderation/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../proxy.ts", import.meta.url), "utf8"),
  ]);
  assert.match(schema, /sqliteTable\("users"/);
  assert.match(schema, /sqliteTable\("library_items"/);
  assert.match(schema, /sqliteTable\("reading_progress"/);
  assert.match(schema, /sqliteTable\("contact_messages"/);
  assert.match(schema, /sqliteTable\("account_tokens"/);
  assert.match(schema, /sqliteTable\("notification_outbox"/);
  assert.match(schema, /sqliteTable\("rate_limit_buckets"/);
  assert.match(schema, /sqliteTable\("reviews"/);
  assert.match(schema, /sqliteTable\("review_reports"/);
  assert.equal(JSON.parse(hosting).d1, "DB");
  assert.match(authActions, /href="\/login"/);
  assert.match(studio, /user\.role !== "admin"/);
  assert.match(library, /Okumaya devam et/);
  assert.match(adSlot, /securepubads\.g\.doubleclick\.net\/tag\/js\/gpt\.js/);
  assert.match(adSlot, /\/6355419\/Travel\/Europe\/France\/Paris/);
  assert.match(adLab, /Reklam Laboratuvarı/);
  assert.match(authControls, /aria-label="Hesap ekranını kapat"/);
  assert.doesNotMatch(studio, /disabled/);
  assert.doesNotMatch(footer, /<span>Hakkımızda|<span>İletişim|<span>Gizlilik/);
  assert.match(notifications, /interface NotificationDelivery/);
  assert.match(notifications, /deliveryFactories/);
  assert.match(notifications, /NotificationDeliveryUnavailableError/);
  assert.match(resetPage, /same-origin/);
  assert.match(accountPage, /\/account\/sessions/);
  assert.match(studio, /href="\/moderation"/);
  assert.match(studio, /href="\/qa"/);
  assert.match(studio, /Manuel QA kuyruğu/);
  assert.match(moderationPage, /Yorumu gizle ve çöz/);
  assert.doesNotMatch(moderationPage, /disabled/);
  assert.match(proxy, /isStudioRequest/);
  assert.match(proxy, /url\.pathname\.startsWith\("\/api\/admin\/"\)/);
});

test("kütüphane aktif durumu, seri takibi ve yeni bölüm bildirimi aynı kalıcı okuyucu akışına bağlıdır", async () => {
  const [schema, database, subscriptions, subscriptionApi, seriesPage, libraryPage, episodeApi, notifications, retention, outboxPage, outboxOpenApi, migration, manualQa] = await Promise.all([
    readFile(new URL("../db/schema.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/database.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/series-subscriptions.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/subscriptions/[slug]/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/[slug]/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/library/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/api/admin/content/episodes/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/notifications.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/notification-outbox.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/studio/outbox/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/api/admin/outbox/[id]/open/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../drizzle/0011_chief_wind_dancer.sql", import.meta.url), "utf8"),
    readFile(new URL("../docs/manual-qa-checklist.md", import.meta.url), "utf8"),
  ]);
  assert.match(schema, /sqliteTable\("series_subscriptions"/);
  assert.match(schema, /notifyNewEpisodes: integer\("notify_new_episodes"/);
  assert.match(database, /CREATE TABLE IF NOT EXISTS series_subscriptions/);
  assert.match(database, /notification_outbox_next/);
  assert.match(migration, /CREATE TABLE `series_subscriptions`/);
  assert.match(migration, /ALTER TABLE `notification_outbox` ADD `dedupe_key`/);
  assert.match(subscriptions, /getSeriesReaderState/);
  assert.match(subscriptions, /toggleSeriesFollow/);
  assert.match(subscriptions, /toggleNewEpisodeNotifications/);
  assert.match(subscriptions, /kind: "new_episode"/);
  assert.match(subscriptions, /dedupeKey: `new-episode:/);
  assert.match(subscriptionApi, /assertSameOrigin/);
  assert.match(subscriptionApi, /subscription\.followed/);
  assert.match(subscriptionApi, /subscription\.notifications_enabled/);
  assert.match(seriesPage, /aria-pressed=\{readerState\.inLibrary\}/);
  assert.match(seriesPage, /Takip ediliyor/);
  assert.match(seriesPage, /Yeni bölüm bildirimi açık/);
  assert.match(libraryPage, /Takip edilenler/);
  assert.match(libraryPage, /action=\{`\/api\/subscriptions\/\$\{row\.series_slug\}`\}/);
  assert.match(episodeApi, /previousEpisode\?\.publicationStatus !== "published"/);
  assert.match(episodeApi, /dispatchNewEpisodeNotifications/);
  assert.match(notifications, /ON CONFLICT\(dedupe_key\) DO NOTHING/);
  assert.match(retention, /OUTBOX_RETENTION_POLICY_VERSION = 2/);
  assert.match(retention, /queuedNewEpisode: 7 \* DAY_MS/);
  assert.match(outboxPage, /new_episode: "Yeni bölüm"/);
  assert.match(outboxOpenApi, /publishedEpisodeAllowed/);
  assert.match(manualQa, /QA-FOL-01/);

  const anonymousSeries = await (await request("/gece-vardiyasi")).text();
  assert.match(anonymousSeries, /action="\/api\/subscriptions\/gece-vardiyasi"/);
  assert.match(anonymousSeries, /aria-pressed="false"/);
  const unauthenticatedFollow = await request("/api/subscriptions/gece-vardiyasi", "text/html", "http://localhost:3000", {
    method: "POST",
    headers: { origin: "http://localhost:3000", "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ action: "follow", return_to: "/gece-vardiyasi" }),
  });
  assert.equal(unauthenticatedFollow.status, 303);
  const followLocation = new URL(unauthenticatedFollow.headers.get("location") ?? "http://localhost:3000");
  assert.equal(followLocation.pathname, "/login");
  assert.equal(followLocation.searchParams.get("return_to"), "/gece-vardiyasi");
});

test("atomik D1 ve Cloudflare edge rate-limit adaptörü fail-closed güvenlik sınırını korur", async () => {
  const [rateLimit, auth, runtimeConfig, envExample, qaPage, manualQa, worker, deployment] = await Promise.all([
    readFile(new URL("../app/lib/rate-limit.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/auth.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/runtime-config.ts", import.meta.url), "utf8"),
    readFile(new URL("../.env.example", import.meta.url), "utf8"),
    readFile(new URL("../app/studio/qa/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../docs/manual-qa-checklist.md", import.meta.url), "utf8"),
    readFile(new URL("../worker/index.ts", import.meta.url), "utf8"),
    readFile(new URL("../docs/rate-limit-deployment.md", import.meta.url), "utf8"),
  ]);
  assert.match(runtimeConfig, /RATE_LIMIT_MODE/);
  assert.match(runtimeConfig, /d1_strict/);
  assert.match(envExample, /RATE_LIMIT_MODE=d1_strict/);
  assert.match(rateLimit, /EDGE_RATE_LIMITER_BINDING = "EDGE_RATE_LIMITER"/);
  assert.match(rateLimit, /SHA256_BASE64_PATTERN = \/\^\[A-Za-z0-9\+\/\]\{43\}=\$\//);
  assert.match(auth, /crypto\.subtle\.digest\("SHA-256", data\)/);
  assert.match(auth, /return bytesToBase64/);
  assert.match(rateLimit, /createRateLimitAdapter/);
  assert.match(rateLimit, /Unsupported rate limit mode/);
  assert.match(rateLimit, /INSERT OR IGNORE INTO rate_limit_buckets/);
  assert.match(rateLimit, /WHERE key = \? AND \(reset_at <= \? OR count < \?\)/);
  assert.doesNotMatch(rateLimit, /SELECT count, reset_at FROM rate_limit_buckets/);
  assert.match(rateLimit, /if \(!await adapter\.consumeEdge\(key\)\) return false;[\s\S]*consumeStrictD1/);
  assert.match(rateLimit, /catch \{[\s\S]*return false;/);
  assert.match(worker, /EDGE_RATE_LIMITER/);
  assert.match(qaPage, /Kötüye kullanım koruması/);
  assert.match(qaPage, /QA-SEC-01/);
  assert.match(manualQa, /QA-SEC-01/);
  assert.match(manualQa, /QA-ACC-05/);
  assert.match(deployment, /120 istek \/ 60 saniye/);
  assert.doesNotMatch(rateLimit, /edge\.limit\(\{ key: (email|client|user|request)/i);

  const response = await request("/api/auth/login", "text/html", "http://localhost", {
    method: "POST",
    headers: { origin: "http://localhost", "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ email: "rate-limit-test@example.invalid", password: "invalid" }),
  });
  assert.equal(response.status, 303);
  const rateLimitError = new URL(response.headers.get("location") ?? "http://localhost").searchParams.get("error") ?? "";
  assert.match(rateLimitError, /Çok fazla giriş denemesi/);
});

test("production platform readiness kapısı binding durumunu secret sızdırmadan raporlar", async () => {
  const [readiness, readinessApi, qaPage, deployment, manualQa, hosting] = await Promise.all([
    readFile(new URL("../app/lib/platform-readiness.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/admin/platform-readiness/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/studio/qa/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../docs/platform-deployment-readiness.md", import.meta.url), "utf8"),
    readFile(new URL("../docs/manual-qa-checklist.md", import.meta.url), "utf8"),
    readFile(new URL("../.openai/hosting.json", import.meta.url), "utf8"),
  ]);
  assert.match(readiness, /PLATFORM_READINESS_SCHEMA_VERSION = "1\.0"/);
  assert.match(readiness, /local_browser/);
  assert.match(readiness, /cloudflare_queue/);
  assert.match(readiness, /d1_strict/);
  assert.match(readiness, /cloudflare_hybrid/);
  assert.match(readiness, /binding-db/);
  assert.match(readiness, /binding-media/);
  assert.match(readiness, /binding-images/);
  assert.match(readiness, /MEDIA_DERIVATIVE_QUEUE_BINDING/);
  assert.match(readiness, /EDGE_RATE_LIMITER_BINDING/);
  assert.match(readiness, /queue-consumer-dlq/);
  assert.match(readiness, /status: profile === "production" \? "manual" : "not_required"/);
  assert.doesNotMatch(readiness, /ADMIN_BOOTSTRAP_TOKEN|password|token|namespace_id/);
  assert.doesNotMatch(readiness, /modes: \{ media: input\.mediaMode/);
  assert.match(readiness, /\? input\.mediaMode : "invalid"/);
  assert.match(readinessApi, /isStudioRequest\(request\)/);
  assert.match(readinessApi, /user\.role !== "admin"/);
  assert.match(readinessApi, /readiness\.automatedReady \? 200 : 503/);
  assert.match(readinessApi, /private, no-store/);
  assert.match(qaPage, /Platform hazırlığı/);
  assert.match(qaPage, /QA-OPS-01/);
  assert.match(manualQa, /QA-OPS-01/);
  assert.match(manualQa, /QA-STU-08/);
  assert.match(deployment, /max_batch_size=3/);
  assert.match(deployment, /max_retries=5/);
  assert.match(deployment, /dead-letter/);
  assert.deepEqual(JSON.parse(hosting), { d1: "DB", r2: "MEDIA" });

  const publicResponse = await request("/api/admin/platform-readiness", "application/json", "http://localhost");
  assert.equal(publicResponse.status, 404);
  const unauthenticatedStudio = await request("/api/admin/platform-readiness", "application/json", "http://studio.localhost:3000");
  assert.equal(unauthenticatedStudio.status, 401);
  assert.match(unauthenticatedStudio.headers.get("cache-control") ?? "", /no-store/);
});

test("Studio public siteden ayrı hostta ve temiz URL'lerle çalışır", async () => {
  const publicStudio = await request("/studio", "text/html", "http://localhost:3000");
  assert.ok([307, 308].includes(publicStudio.status));
  assert.equal(publicStudio.headers.get("location"), "http://studio.localhost:3000/");

  const studioRoot = await request("/", "text/html", "http://studio.localhost:3000");
  assert.ok([307, 308].includes(studioRoot.status));
  assert.equal(studioRoot.headers.get("location"), "http://studio.localhost:3000/login?return_to=/");

  const publicAdminMutation = await request("/api/admin/messages/example", "text/html", "http://localhost", { method: "POST" });
  assert.equal(publicAdminMutation.status, 404);

  const publicPreviewMutation = await request("/api/admin/previews", "text/html", "http://localhost", { method: "POST" });
  assert.equal(publicPreviewMutation.status, 404);
  const publicDerivativeMutation = await request("/api/admin/media/derivatives", "text/html", "http://localhost", { method: "POST" });
  assert.equal(publicDerivativeMutation.status, 404);
  const publicRoleMutation = await request("/api/admin/users/example/role", "text/html", "http://localhost", { method: "POST" });
  assert.equal(publicRoleMutation.status, 404);
  const publicInvitationMutation = await request("/api/admin/invitations", "text/html", "http://localhost", { method: "POST" });
  assert.equal(publicInvitationMutation.status, 404);
  const publicOutboxRetention = await request("/api/admin/outbox/retention", "text/html", "http://localhost", { method: "POST" });
  assert.equal(publicOutboxRetention.status, 404);

  for (const path of ["/accept-admin-invite", "/bootstrap-admin"]) {
    const publicResponse = await request(path, "text/html", "http://localhost:3000");
    assert.ok([307, 308].includes(publicResponse.status), `${path} Studio hostuna yönlenmeli`);
    const studioResponse = await request(path, "text/html", "http://studio.localhost:3000");
    assert.equal(studioResponse.status, 200, `${path} Studio hostunda açılmalı`);
    assert.match(await studioResponse.text(), /noindex/);
  }

  for (const path of ["/users", "/audit", "/qa"]) {
    const response = await request(path, "text/html", "http://studio.localhost:3000");
    assert.ok([307, 308].includes(response.status), `${path} girişe yönlenmeli`);
  }
});

test("Studio kullanıcı rolleri ve audit günlüğü güvenlik sınırlarını korur", async () => {
  const [dashboard, usersPage, auditPage, adminRepository, roleApi, proxy] = await Promise.all([
    readFile(new URL("../app/studio/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/studio/users/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/studio/audit/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/studio-admin.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/admin/users/[id]/role/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../proxy.ts", import.meta.url), "utf8"),
  ]);
  assert.match(dashboard, /href="\/users"/);
  assert.match(dashboard, /href="\/audit"/);
  assert.match(usersPage, /Kendi rolün bu ekrandan değiştirilemez/);
  assert.match(usersPage, /son yönetici okuyucuya dönüştürülemez/i);
  assert.match(auditPage, /Gizlilik:/);
  assert.match(auditPage, /Daha eski kayıtlar/);
  assert.match(adminRepository, /safeMetadata/);
  assert.match(adminRepository, /const allowed = new Set/);
  assert.doesNotMatch(adminRepository, /password_hash|token_hash|action_url/);
  assert.match(roleApi, /isStudioRequest\(request\)/);
  assert.match(roleApi, /assertSameOrigin/);
  assert.match(roleApi, /targetUserId === actor\.id/);
  assert.match(roleApi, /COUNT\(\*\) FROM users WHERE role = 'admin'/);
  assert.match(roleApi, /DELETE FROM sessions WHERE user_id = \?/);
  assert.match(roleApi, /admin\.user_role_changed/);
  assert.match(proxy, /"users"/);
  assert.match(proxy, /"audit"/);
});

test("Studio yönetici daveti hashli, tek kullanımlık ve production kaydı yetkisiz başlatmaz", async () => {
  const [schema, invitations, invitationApi, invitationUpdateApi, acceptApi, bootstrapApi, runtimeConfig, registerApi, auth, usersPage, outboxApi, proxy] = await Promise.all([
    readFile(new URL("../db/schema.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/admin-invitations.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/admin/invitations/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/admin/invitations/[id]/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/auth/admin-invitation/accept/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/auth/admin-bootstrap/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/runtime-config.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/auth/register/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/auth.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/studio/users/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/api/admin/outbox/[id]/open/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../proxy.ts", import.meta.url), "utf8"),
  ]);
  assert.match(schema, /sqliteTable\("admin_invitations"/);
  assert.match(schema, /admin_invitations_pending_email_unique/);
  assert.match(invitations, /INVITATION_TTL_MS = 24 \* 60 \* 60 \* 1000/);
  assert.match(invitations, /createOpaqueToken\(\)/);
  assert.match(invitations, /hashOpaqueToken\(rawToken\)/);
  assert.doesNotMatch(invitations, /rawToken[^\n]*INSERT|INSERT[^\n]*rawToken/);
  assert.match(invitationApi, /isStudioRequest\(request\)/);
  assert.match(invitationApi, /assertSameOrigin/);
  assert.match(invitationApi, /admin\.invitation_created/);
  assert.match(invitationUpdateApi, /admin\.invitation_resent/);
  assert.match(invitationUpdateApi, /admin\.invitation_revoked/);
  assert.match(invitationUpdateApi, /consumeRateLimit\("admin-invitation-update"/);
  assert.match(acceptApi, /admin\.invitation_accepted/);
  assert.match(runtimeConfig, /ADMIN_BOOTSTRAP_TOKEN/);
  assert.match(runtimeConfig, /cloudflare:workers/);
  assert.match(bootstrapApi, /expectedToken\.length < 32/);
  assert.match(bootstrapApi, /hasAdminAccount\(\)/);
  assert.match(bootstrapApi, /admin\.bootstrap_completed/);
  assert.doesNotMatch(bootstrapApi, /console\.(log|info|debug)[\s\S]*Token/);
  assert.doesNotMatch(`${invitationApi}\n${invitationUpdateApi}\n${acceptApi}`, /console\.error\([^\n]*,\s*error\)/);
  assert.match(registerApi, /isLocalQaRequest\(request\)/);
  assert.match(auth, /allowLocalFirstAdmin/);
  assert.match(auth, /allowLocalFirstAdmin && Number\(count\?\.count/);
  assert.match(usersPage, /action="\/api\/admin\/invitations"/);
  assert.match(usersPage, /Bağlantıyı yenile/);
  assert.match(usersPage, /Daveti iptal et/);
  assert.match(outboxApi, /\/accept-admin-invite/);
  assert.match(proxy, /"\/accept-admin-invite", "\/bootstrap-admin"/);
});

test("bildirim adaptörü ve outbox saklama politikası fail-closed yönetim sınırını korur", async () => {
  const [notifications, runtimeConfig, retention, retentionApi, outboxPage, outboxOpenApi, auditRepository, auditPage, agents, manualQa, qaPage, proxy] = await Promise.all([
    readFile(new URL("../app/lib/notifications.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/runtime-config.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/notification-outbox.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/admin/outbox/retention/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/studio/outbox/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/api/admin/outbox/[id]/open/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/studio-admin.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/studio/audit/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../AGENTS.md", import.meta.url), "utf8"),
    readFile(new URL("../docs/manual-qa-checklist.md", import.meta.url), "utf8"),
    readFile(new URL("../app/studio/qa/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../proxy.ts", import.meta.url), "utf8"),
  ]);
  assert.match(runtimeConfig, /NOTIFICATION_DELIVERY_MODE/);
  assert.match(runtimeConfig, /local_outbox/);
  assert.match(notifications, /Record<NotificationDeliveryMode, DeliveryFactory>/);
  assert.match(notifications, /if \(!factory\) throw new NotificationDeliveryUnavailableError/);
  assert.match(retention, /OUTBOX_RETENTION_POLICY_VERSION = 2/);
  assert.match(retention, /queuedPasswordReset: 1 \* DAY_MS/);
  assert.match(retention, /queuedVerification: 2 \* DAY_MS/);
  assert.match(retention, /queuedAdminInvitation: 2 \* DAY_MS/);
  assert.match(retention, /queuedSecurityNotice: 30 \* DAY_MS/);
  assert.match(retention, /queuedNewEpisode: 7 \* DAY_MS/);
  assert.match(retention, /DELETE FROM notification_outbox WHERE/);
  assert.match(retentionApi, /isStudioRequest\(request\)/);
  assert.match(retentionApi, /assertSameOrigin/);
  assert.match(retentionApi, /consumeRateLimit\("admin-outbox-retention"/);
  assert.match(retentionApi, /admin\.notification_outbox_purged/);
  assert.doesNotMatch(retentionApi, /console\.error\([^\n]*,\s*error\)/);
  assert.match(outboxOpenApi, /isStudioRequest\(request\)/);
  assert.match(outboxPage, /action="\/api\/admin\/outbox\/retention"/);
  assert.match(outboxPage, /Süresi dolanları temizle/);
  assert.doesNotMatch(outboxPage, /disabled/);
  assert.match(auditRepository, /"deletedCount", "policyVersion"/);
  assert.match(auditPage, /admin\.notification_outbox_purged/);
  assert.match(agents, /docs\/manual-qa-checklist\.md/);
  assert.match(manualQa, /QA-ADM-01/);
  assert.match(manualQa, /QA-STU-06/);
  assert.match(manualQa, /QA-MED-02/);
  assert.match(qaPage, /docs\/manual-qa-checklist\.md/);
  assert.match(qaPage, /QA-ADM-01/);
  assert.match(qaPage, /QA-MED-02/);
  assert.match(proxy, /"qa"/);

  const unauthenticatedStudioMutation = await request("/api/admin/outbox/retention", "text/html", "http://studio.localhost:3000", {
    method: "POST",
    headers: { origin: "http://studio.localhost:3000" },
  });
  assert.equal(unauthenticatedStudioMutation.status, 303);
  assert.equal(unauthenticatedStudioMutation.headers.get("location"), "http://studio.localhost:3000/login?return_to=/outbox");
});

test("taslak önizleme süreli, kapsamlı ve public yayından ayrıdır", async () => {
  const [schema, previewTokens, previewApi, previewMedia, previewPage, seriesStudioPage, proxy] = await Promise.all([
    readFile(new URL("../db/schema.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/preview-tokens.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/admin/previews/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/preview/media/[id]/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/preview/[token]/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/studio/content/[slug]/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../proxy.ts", import.meta.url), "utf8"),
  ]);
  assert.match(schema, /sqliteTable\("preview_tokens"/);
  assert.match(schema, /uniqueIndex\("preview_tokens_hash_unique"/);
  assert.match(previewTokens, /new Uint8Array\(32\)/);
  assert.match(previewTokens, /crypto\.subtle\.digest\("SHA-256"/);
  assert.match(previewTokens, /PREVIEW_TTL_MS = 30 \* 60 \* 1000/);
  assert.doesNotMatch(previewTokens, /rawToken[^\n]*INSERT|INSERT[^\n]*rawToken/);
  assert.match(previewApi, /isStudioRequest\(request\)/);
  assert.match(previewApi, /assertSameOrigin/);
  assert.match(previewApi, /preview\.created/);
  assert.match(previewApi, /preview\.revoked/);
  assert.match(previewMedia, /asset\.seriesSlug !== grant\.seriesSlug/);
  assert.match(previewMedia, /Cache-Control["']:\s*["']private, no-store/);
  assert.match(previewPage, /robots:\s*\{ index: false, follow: false/);
  assert.match(seriesStudioPage, /PreviewCreateForm/);
  assert.match(proxy, /X-Robots-Tag/);

  const invalidPage = await request("/preview/not-a-valid-token");
  assert.equal(invalidPage.status, 404);
  assert.equal(invalidPage.headers.get("referrer-policy"), "no-referrer");
  assert.match(invalidPage.headers.get("cache-control") ?? "", /no-store/);
  assert.match(invalidPage.headers.get("x-robots-tag") ?? "", /noindex/);

  const invalidMedia = await request("/api/preview/media/example?token=invalid", "image/webp");
  assert.equal(invalidMedia.status, 404);
  assert.match(invalidMedia.headers.get("cache-control") ?? "", /no-store/);
});

test("şifre sıfırlama ve doğrulama sayfaları herkese açıktır", async () => {
  for (const path of ["/forgot-password", "/reset-password", "/verify-email"]) {
    const response = await request(path);
    assert.equal(response.status, 200, `${path} 200 dönmeli`);
  }
  const login = await (await request("/login")).text();
  assert.match(login, /href="\/forgot-password"/);
});

test("Studio içerik CRUD ve D1 yayın sınırı kaynakta korunur", async () => {
  const [schema, repository, contentPage, seriesApi, episodeApi] = await Promise.all([
    readFile(new URL("../db/schema.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/content-repository.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/studio/content/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/api/admin/content/series/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/admin/content/episodes/route.ts", import.meta.url), "utf8"),
  ]);
  assert.match(schema, /sqliteTable\("content_series"/);
  assert.match(schema, /sqliteTable\("content_episodes"/);
  assert.match(contentPage, /href="\/content\/new"/);
  assert.match(repository, /publicationStatus === "published"/);
  assert.match(repository, /function toPublicSeries/);
  assert.match(repository, /function toPublicSeries[\s\S]*publishedAt: episode\.publishedAt/);
  assert.match(seriesApi, /isStudioRequest\(request\)/);
  assert.match(episodeApi, /isStudioRequest\(request\)/);
  assert.match(seriesApi, /writeAudit/);
  assert.match(episodeApi, /writeAudit/);
});
test("Studio medya hattı R2, responsive kuyruk, host sınırı ve yayın görünürlüğü sözleşmesini korur", async () => {
  const [schema, hosting, mediaApi, mediaManageApi, derivativesApi, redispatchApi, derivatives, dispatch, derivativeQueue, consumer, worker, privateMedia, publicMedia, validation, storage, mediaPage, episodePage, reader, proxy, envExample] = await Promise.all([
    readFile(new URL("../db/schema.ts", import.meta.url), "utf8"),
    readFile(new URL("../.openai/hosting.json", import.meta.url), "utf8"),
    readFile(new URL("../app/api/admin/media/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/admin/media/manage/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/admin/media/derivatives/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/admin/media/derivatives/dispatch/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/media/derivatives.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/media/derivative-dispatch.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/studio/media/DerivativeQueue.tsx", import.meta.url), "utf8"),
    readFile(new URL("../worker/media-derivative-consumer.ts", import.meta.url), "utf8"),
    readFile(new URL("../worker/index.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/admin/media/[id]/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/media/[id]/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/media/image-validation.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/media/storage.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/studio/media/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/studio/content/[slug]/episodes/[episode]/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/[slug]/[episode]/ReaderExperience.tsx", import.meta.url), "utf8"),
    readFile(new URL("../proxy.ts", import.meta.url), "utf8"),
    readFile(new URL("../.env.example", import.meta.url), "utf8"),
  ]);
  assert.equal(JSON.parse(hosting).r2, "MEDIA");
  assert.match(schema, /sqliteTable\("media_assets"/);
  assert.match(schema, /sqliteTable\("media_variants"/);
  assert.match(schema, /sqliteTable\("media_derivative_jobs"/);
  assert.match(schema, /storage_key/);
  assert.match(mediaApi, /isStudioRequest\(request\)/);
  assert.match(mediaApi, /assertSameOrigin/);
  assert.match(mediaApi, /writeAudit\(user\.id, "media\.uploaded"/);
  assert.match(mediaApi, /crypto\.subtle\.digest\("SHA-256"/);
  assert.match(privateMedia, /user\.role !== "admin"/);
  assert.match(publicMedia, /isPublicMediaAsset/);
  assert.match(validation, /image\/jpeg/);
  assert.match(validation, /image\/png/);
  assert.match(validation, /image\/webp/);
  assert.match(validation, /MAX_PIXELS/);
  assert.match(validation, /inspectDerivative/);
  assert.match(storage, /interface MediaStorage/);
  assert.match(storage, /env\.MEDIA/);
  assert.match(mediaPage, /multipart\/form-data/);
  assert.match(mediaPage, /Dosyayı doğrula ve yükle/);
  assert.match(mediaPage, /Türetme kuyruğu/);
  assert.match(dispatch, /RESPONSIVE_WIDTHS = \[480, 768, 1200\]/);
  assert.match(derivatives, /INSERT OR IGNORE INTO media_derivative_jobs/);
  assert.match(schema, /dispatchMode: text\("dispatch_mode"/);
  assert.match(schema, /dispatchStatus: text\("dispatch_status"/);
  assert.match(envExample, /MEDIA_DERIVATIVE_DISPATCH_MODE=local_browser/);
  assert.match(dispatch, /MEDIA_DERIVATIVE_TASK_VERSION = 1/);
  assert.match(dispatch, /MEDIA_DERIVATIVE_QUEUE_BINDING = "MEDIA_DERIVATIVE_QUEUE"/);
  assert.match(dispatch, /Unsupported media derivative dispatch mode/);
  assert.doesNotMatch(dispatch, /storageKey|token|cookie|secret/i);
  assert.match(derivativeQueue, /createImageBitmap/);
  assert.match(derivativeQueue, /image\/webp/);
  assert.match(derivativeQueue, /Cloudflare üretim kuyruğu/);
  assert.match(derivativeQueue, /\/api\/admin\/media\/derivatives\/dispatch/);
  assert.match(derivativesApi, /inspectDerivative/);
  assert.match(derivativesApi, /isStudioRequest\(request\)/);
  assert.match(derivativesApi, /assertSameOrigin/);
  assert.match(derivativesApi, /media\.derivative_completed/);
  assert.match(redispatchApi, /isStudioRequest\(request\)/);
  assert.match(redispatchApi, /assertSameOrigin/);
  assert.match(redispatchApi, /user\.role !== "admin"/);
  assert.match(consumer, /parseMediaDerivativeTask/);
  assert.match(consumer, /INSERT OR IGNORE INTO media_variants/);
  assert.match(consumer, /status = 'processing'/);
  assert.match(consumer, /inspectDerivative/);
  assert.match(consumer, /media\.derivative_worker_completed/);
  assert.match(worker, /async queue\(batch: QueueBatch/);
  assert.match(worker, /message\.retry\(\{ delaySeconds: 30 \}\)/);
  assert.match(publicMedia, /getMediaVariant/);
  assert.match(reader, /srcSet=/);
  assert.match(mediaPage, /cover_restore/);
  assert.match(episodePage, /panel_move/);
  assert.match(episodePage, /panel_remove/);
  assert.match(mediaManageApi, /media\.panel_reordered/);
  assert.match(mediaManageApi, /media\.panel_unlinked/);
  assert.match(mediaManageApi, /media\.cover_restored/);
  assert.match(mediaManageApi, /isStudioRequest/);
  assert.match(proxy, /"media"/);
});
