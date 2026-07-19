import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const [manifest, fixtureSource, routeSource, pageSource] = await Promise.all([
  readFile(new URL("../app/data/local-qa-fixtures.json", import.meta.url), "utf8").then(JSON.parse),
  readFile(new URL("../app/lib/local-qa-fixtures.ts", import.meta.url), "utf8"),
  readFile(new URL("../app/api/admin/qa-fixtures/route.ts", import.meta.url), "utf8"),
  readFile(new URL("../app/studio/qa/page.tsx", import.meta.url), "utf8"),
]);

test("yerel QA manifesti deterministik kabul verisini kapsar", () => {
  assert.equal(manifest.version, 1);
  assert.equal(manifest.users.length, 3);
  assert.equal(manifest.series.filter((series) => series.publicationStatus === "published").length, 8);
  assert.equal(manifest.series.filter((series) => series.publicationStatus === "draft").length, 1);
  assert.equal(manifest.series.filter((series) => series.publicationStatus === "archived").length, 1);
  assert.ok(manifest.reviews.length >= 3);
  assert.ok(manifest.reports.some((report) => report.status === "open"));
  assert.ok(manifest.outbox.some((message) => message.status === "opened" && message.ageHours > 24));

  const userIds = new Set(manifest.users.map((user) => user.id));
  const seriesSlugs = new Set(manifest.series.map((series) => series.slug));
  assert.equal(userIds.size, manifest.users.length);
  assert.equal(seriesSlugs.size, manifest.series.length);
  for (const user of manifest.users) {
    assert.match(user.id, /^qa_fixture_user_/);
    assert.match(user.email, /^qa-.*@panelya\.local$/);
    assert.equal("password" in user, false);
  }
  for (const series of manifest.series) {
    assert.match(series.slug, /^qa-fixture-/);
    assert.match(series.episode.id, /^qa_fixture_episode_/);
  }
  for (const item of [...manifest.library, ...manifest.subscriptions, ...manifest.progress, ...manifest.reviews]) {
    assert.ok(userIds.has(item.userId));
    assert.ok(seriesSlugs.has(item.seriesSlug));
  }
});

test("QA mutation'i production ve yetki sinirlarinin arkasindadir", () => {
  assert.match(routeSource, /!isStudioRequest\(request\) \|\| !isLocalQaRequest\(request\)/);
  assert.match(routeSource, /assertSameOrigin\(request\)/);
  assert.match(routeSource, /actor\.role !== "admin"/);
  assert.match(routeSource, /hasRecentAuthentication\(\)/);
  assert.match(routeSource, /consumeRateLimit\("admin-qa-fixtures"/);
  assert.match(routeSource, /seedLocalQaFixtures\(password\)/);
  assert.match(routeSource, /resetLocalQaFixtures\(\)/);
  assert.doesNotMatch(routeSource, /console\.(?:log|error)\([^\n]*(?:password|fixture_password)/i);
});

test("QA sifirlama yalniz sentetik ad alanini hedefler", () => {
  assert.match(fixtureSource, /const USER_ID_GLOB = "qa_fixture_user_\*"/);
  assert.match(fixtureSource, /const SERIES_SLUG_GLOB = "qa-fixture-\*"/);
  assert.match(fixtureSource, /DELETE FROM users WHERE id GLOB \? OR email GLOB \?/);
  assert.match(fixtureSource, /DELETE FROM content_series WHERE slug GLOB \?/);
  assert.doesNotMatch(fixtureSource, /DELETE FROM (?:users|content_series)(?:`|")\s*\)/);
  assert.match(pageSource, /action="\/api\/admin\/qa-fixtures"/);
  assert.match(pageSource, /name="fixture_password"/);
  assert.match(pageSource, /recentAuthenticationHref\("\/qa"\)/);
});
