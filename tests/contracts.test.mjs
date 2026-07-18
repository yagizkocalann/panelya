import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
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
  series: validator("SeriesDetailResponse"),
  manifest: validator("EpisodeManifestResponse"),
  error: validator("ErrorResponse"),
};

const fixtureCases = [
  ["catalog.v1.json", validators.catalog],
  ["series-detail.v1.json", validators.series],
  ["episode-manifest.v1.json", validators.manifest],
];

test("OpenAPI path'leri mevcut JSON Schema tanımlarına bağlanır", async () => {
  const openapi = JSON.parse(
    await readFile(new URL("../packages/contracts/openapi.json", import.meta.url), "utf8"),
  );
  assert.equal(openapi.openapi, "3.1.0");
  assert.deepEqual(
    Object.keys(openapi.paths).sort(),
    [
      "/api/catalog",
      "/api/series/{slug}",
      "/api/series/{slug}/episodes/{episodeSlug}",
    ],
  );

  const refs = JSON.stringify(openapi).match(/\.\/schema\.json#\/\$defs\/[A-Za-z]+/g) ?? [];
  assert.ok(refs.length >= 5, "OpenAPI response'ları ortak schema tanımlarına bağlanmalı");
  for (const ref of refs) {
    const definition = ref.split("/").at(-1);
    assert.ok(contract.$defs[definition], `${ref} mevcut bir tanıma işaret etmeli`);
  }
});

test("paylaşılan fixture'lar JSON Schema sözleşmesine uyar", async () => {
  for (const [filename, validate] of fixtureCases) {
    const fixture = JSON.parse(
      await readFile(new URL(`../packages/contracts/fixtures/${filename}`, import.meta.url), "utf8"),
    );
    assertContract(validate, fixture, filename);
  }
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

test("public API 404 cevapları ortak hata sözleşmesine uyar", async () => {
  const seriesResponse = await request("/api/series/olmayan-seri");
  assert.equal(seriesResponse.status, 404);
  assertContract(validators.error, await seriesResponse.json(), "series 404");

  const episodeResponse = await request("/api/series/olmayan-seri/episodes/olmayan-bolum");
  assert.equal(episodeResponse.status, 404);
  assertContract(validators.error, await episodeResponse.json(), "episode 404");
});
