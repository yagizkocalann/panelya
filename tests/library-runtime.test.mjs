import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const [listRoute, itemRoute, actorRuntime, authRuntime, libraryRuntime] = await Promise.all([
  readFile(new URL("../app/api/library/route.ts", import.meta.url), "utf8"),
  readFile(new URL("../app/api/library/[slug]/route.ts", import.meta.url), "utf8"),
  readFile(new URL("../app/lib/account-runtime.ts", import.meta.url), "utf8"),
  readFile(new URL("../app/lib/auth0-runtime.ts", import.meta.url), "utf8"),
  readFile(new URL("../app/lib/library-runtime.ts", import.meta.url), "utf8"),
]);

test("kütüphane Bearer erişimi gerekli scope'ları JWT doğrulamasına taşır", () => {
  assert.match(listRoute, /requireAccountActor\(request, \["read:library"\]\)/);
  assert.match(itemRoute, /requireAccountActor\(request, \["write:library"\]\)/g);
  assert.match(actorRuntime, /identityFromBearerToken\(request, config, requiredScopes\)/);
  assert.match(authRuntime, /validateAuth0AccessToken\(match\[1\], config, requiredScopes\)/);
});

test("JSON kütüphane mutation'ı tam durum ve exact-key sınırını korur", () => {
  assert.match(itemRoute, /objectInput\([\s\S]*\["status", "favorite"\]\)/);
  assert.match(itemRoute, /assertAccountMutationOrigin\(request, actor\)/);
  assert.match(itemRoute, /request\.formData\(\)/, "mevcut server-rendered web formu korunmalı");
  assert.match(itemRoute, /parseLibraryFavorite\(input\.favorite\)/, "JSON API hedef favorite durumunu okumalı");
});

test("kütüphane cevabı yalnız public seri özetini taşır", () => {
  assert.match(libraryRuntime, /episodeCount: series\.episodes\.length/);
  assert.doesNotMatch(libraryRuntime, /storageKey|jobId|queueId/);
  assert.match(libraryRuntime, /ORDER BY updated_at DESC, series_slug ASC/);
});
