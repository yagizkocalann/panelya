import assert from "node:assert/strict";
import test from "node:test";

// Universal Links (iOS) / App Links (Android) — AASA + assetlinks.json (bkz.
// apps/mobile/README.md "Gelecek adım" -> gerçekleşen durum,
// production-bible.md yeni ADR). Bu dosya, gerçek derlenmiş worker'a karşı
// (bkz. tests/auth0-runtime.test.mjs ile aynı desen) `/.well-known/*`
// isteklerinin: (1) `next.config.ts`teki rewrite ile doğru dosya tabanlı
// route'a ulaştığını, (2) ortam değişkenleri eksikken FAIL-CLOSED 503
// döndüğünü (SAHTE appID/paket adı/parmak izi ÜRETİLMEDİĞİNİ), (3) tam
// yapılandırmada doğru JSON gövde + `Content-Type: application/json` +
// cache header'ları döndürdüğünü doğrular.

const ENV_KEYS = [
  "APPLE_TEAM_ID",
  "APPLE_BUNDLE_ID",
  "ANDROID_PACKAGE_NAME",
  "ANDROID_SHA256_FINGERPRINTS",
];

function clearAssociatedDomainsEnv() {
  for (const key of ENV_KEYS) delete process.env[key];
}

clearAssociatedDomainsEnv();

const workerUrl = new URL("../dist/server/index.js", import.meta.url);
workerUrl.searchParams.set("associated-domains-test", `${process.pid}-${Date.now()}`);
const { default: worker } = await import(workerUrl.href);

const baseEnv = { ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) } };
const executionContext = {
  waitUntil() {},
  passThroughOnException() {},
};

async function fetchWellKnown(path) {
  return worker.fetch(
    new Request(`http://localhost${path}`, { headers: { accept: "application/json" } }),
    baseEnv,
    executionContext,
  );
}

test("hiçbir ortam değişkeni ayarlanmamışken AASA fail-closed 503 döner, sahte appID üretilmez", async () => {
  clearAssociatedDomainsEnv();
  const response = await fetchWellKnown("/.well-known/apple-app-site-association");
  assert.equal(response.status, 503);
  assert.equal(response.headers.get("content-type"), "application/json");
  assert.match(response.headers.get("cache-control") ?? "", /no-store/);
  const body = await response.json();
  assert.equal(body.error, "service_unavailable");
  assert.match(body.errorDescription, /APPLE_TEAM_ID/);
  assert.match(body.errorDescription, /APPLE_BUNDLE_ID/);
  // Hiçbir gerçek/uydurma appID sızmamalı.
  assert.doesNotMatch(JSON.stringify(body), /applinks|appID/);
});

test("hiçbir ortam değişkeni ayarlanmamışken assetlinks.json fail-closed 503 döner, sahte paket adı/parmak izi üretilmez", async () => {
  clearAssociatedDomainsEnv();
  const response = await fetchWellKnown("/.well-known/assetlinks.json");
  assert.equal(response.status, 503);
  assert.equal(response.headers.get("content-type"), "application/json");
  assert.match(response.headers.get("cache-control") ?? "", /no-store/);
  const body = await response.json();
  assert.equal(body.error, "service_unavailable");
  assert.match(body.errorDescription, /ANDROID_PACKAGE_NAME/);
  assert.match(body.errorDescription, /ANDROID_SHA256_FINGERPRINTS/);
  assert.doesNotMatch(JSON.stringify(body), /sha256_cert_fingerprints|package_name/);
});

test("APPLE_BUNDLE_ID eksikken (APPLE_TEAM_ID doluyken de) AASA yine fail-closed kalır", async () => {
  clearAssociatedDomainsEnv();
  process.env.APPLE_TEAM_ID = "ABCDE12345";
  const response = await fetchWellKnown("/.well-known/apple-app-site-association");
  assert.equal(response.status, 503);
  clearAssociatedDomainsEnv();
});

test("ANDROID_SHA256_FINGERPRINTS eksikken (ANDROID_PACKAGE_NAME doluyken de) assetlinks yine fail-closed kalır", async () => {
  clearAssociatedDomainsEnv();
  process.env.ANDROID_PACKAGE_NAME = "com.panelya.panelya_mobile";
  const response = await fetchWellKnown("/.well-known/assetlinks.json");
  assert.equal(response.status, 503);
  clearAssociatedDomainsEnv();
});

test("tam yapılandırmada AASA doğru appID sözdizimini (<TeamID>.<BundleID>), Content-Type ve cache header'larını döner", async () => {
  clearAssociatedDomainsEnv();
  process.env.APPLE_TEAM_ID = "ABCDE12345";
  process.env.APPLE_BUNDLE_ID = "com.panelya.panelyaMobile";
  try {
    const response = await fetchWellKnown("/.well-known/apple-app-site-association");
    assert.equal(response.status, 200);
    assert.equal(response.headers.get("content-type"), "application/json");
    assert.match(response.headers.get("cache-control") ?? "", /public/);
    assert.match(response.headers.get("cache-control") ?? "", /max-age=3600/);
    const body = await response.json();
    assert.deepEqual(body, {
      applinks: {
        apps: [],
        details: [
          {
            appID: "ABCDE12345.com.panelya.panelyaMobile",
            appIDs: ["ABCDE12345.com.panelya.panelyaMobile"],
            paths: ["/*"],
          },
        ],
      },
    });
  } finally {
    clearAssociatedDomainsEnv();
  }
});

test("tam yapılandırmada assetlinks.json doğru gövdeyi döner ve virgülle ayrılmış BİRDEN FAZLA SHA-256 parmak izini ayrıştırır", async () => {
  clearAssociatedDomainsEnv();
  process.env.ANDROID_PACKAGE_NAME = "com.panelya.panelya_mobile";
  process.env.ANDROID_SHA256_FINGERPRINTS = " AA:BB:CC:11 , DD:EE:FF:22 ";
  try {
    const response = await fetchWellKnown("/.well-known/assetlinks.json");
    assert.equal(response.status, 200);
    assert.equal(response.headers.get("content-type"), "application/json");
    assert.match(response.headers.get("cache-control") ?? "", /public/);
    const body = await response.json();
    assert.deepEqual(body, [
      {
        relation: ["delegate_permission/common.handle_all_urls"],
        target: {
          namespace: "android_app",
          package_name: "com.panelya.panelya_mobile",
          // Baştaki/sondaki boşluklar kırpılmış olmalı (kopyala-yapıştır
          // hatalarına karşı toleranslı, ama sahte bir değer eklenmemiş).
          sha256_cert_fingerprints: ["AA:BB:CC:11", "DD:EE:FF:22"],
        },
      },
    ]);
  } finally {
    clearAssociatedDomainsEnv();
  }
});

test("`/.well-known/*` yönlendirmesi (next.config.ts rewrite) istemciye görünmez — 404 DEĞİL, doğrudan 200/503 döner", async () => {
  // Bu testin kendisi zaten yukarıdaki her testte dolaylı olarak
  // doğrulanıyor (worker'a TAM OLARAK `/.well-known/...` path'i ile istek
  // atılıyor, dahili `/well-known/...` route'una ASLA doğrudan gidilmiyor);
  // burada ayrıca 404 OLMADIĞINI açıkça sabitliyoruz — dosya tabanlı
  // rota bulunamazsa (rewrite çalışmazsa) worker 404 dönerdi.
  clearAssociatedDomainsEnv();
  const response = await fetchWellKnown("/.well-known/apple-app-site-association");
  assert.notEqual(response.status, 404);
});
