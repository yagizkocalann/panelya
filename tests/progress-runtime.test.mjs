import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const [route, runtime, reader] = await Promise.all([
  readFile(new URL("../app/api/progress/route.ts", import.meta.url), "utf8"),
  readFile(new URL("../app/lib/progress-runtime.ts", import.meta.url), "utf8"),
  readFile(new URL("../app/[slug]/[episode]/ReaderExperience.tsx", import.meta.url), "utf8"),
]);

test("okuma ilerlemesi cookie ve Bearer icin ayni write:progress sinirini kullanir", () => {
  assert.match(route, /requireAccountActor\(request, \["write:progress"\]\)/);
  assert.match(route, /getAccountActor\(request, \["write:progress"\]\)/);
  assert.match(route, /assertAccountMutationOrigin\(request, actor\)/);
});

test("ilerleme mutation'i exact-key tam konum ve sinirli yuzde ister", () => {
  assert.match(route, /\["seriesSlug", "episodeSlug", "percent"\]/);
  assert.match(runtime, /Number\.isInteger\(value\)/);
  assert.match(runtime, /value < 0 \|\| value > 100/);
  assert.match(runtime, /ON CONFLICT\(user_id, series_slug\) DO UPDATE SET/);
});

test("ilerleme cevabi yalniz yayinlanmis public ozetleri tasir", () => {
  assert.match(runtime, /ORDER BY updated_at DESC, series_slug ASC/);
  assert.match(runtime, /panelCount: episode\.panels\.length/);
  assert.doesNotMatch(runtime, /storageKey|jobId|queueId/);
});

test("mevcut web okuyucu cihaz ici ilerleme ve anonim no-op davranisini korur", () => {
  assert.match(reader, /panelya:progress:/);
  assert.match(reader, /panelya:last:/);
  assert.match(reader, /fetch\("\/api\/progress"/);
  assert.match(route, /if \(!actor\) return new Response\(null, \{ status: 204/);
});
