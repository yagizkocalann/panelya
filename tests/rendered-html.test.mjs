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
  assert.match(resetPage, /same-origin/);
  assert.match(accountPage, /\/account\/sessions/);
  assert.match(studio, /href="\/moderation"/);
  assert.match(moderationPage, /Yorumu gizle ve çöz/);
  assert.doesNotMatch(moderationPage, /disabled/);
  assert.match(proxy, /isStudioRequest/);
  assert.match(proxy, /url\.pathname\.startsWith\("\/api\/admin\/"\)/);
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
test("Studio medya hattı R2, host sınırı ve yayın görünürlüğü sözleşmesini korur", async () => {
  const [schema, hosting, mediaApi, mediaManageApi, privateMedia, publicMedia, validation, storage, mediaPage, episodePage, proxy] = await Promise.all([
    readFile(new URL("../db/schema.ts", import.meta.url), "utf8"),
    readFile(new URL("../.openai/hosting.json", import.meta.url), "utf8"),
    readFile(new URL("../app/api/admin/media/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/admin/media/manage/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/admin/media/[id]/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/media/[id]/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/media/image-validation.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/media/storage.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/studio/media/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/studio/content/[slug]/episodes/[episode]/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../proxy.ts", import.meta.url), "utf8"),
  ]);
  assert.equal(JSON.parse(hosting).r2, "MEDIA");
  assert.match(schema, /sqliteTable\("media_assets"/);
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
  assert.match(storage, /interface MediaStorage/);
  assert.match(storage, /env\.MEDIA/);
  assert.match(mediaPage, /multipart\/form-data/);
  assert.match(mediaPage, /Dosyayı doğrula ve yükle/);
  assert.match(mediaPage, /cover_restore/);
  assert.match(episodePage, /panel_move/);
  assert.match(episodePage, /panel_remove/);
  assert.match(mediaManageApi, /media\.panel_reordered/);
  assert.match(mediaManageApi, /media\.panel_unlinked/);
  assert.match(mediaManageApi, /media\.cover_restored/);
  assert.match(mediaManageApi, /isStudioRequest/);
  assert.match(proxy, /"media"/);
});
