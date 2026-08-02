import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { checkPerformanceBudgets } from "../scripts/check-performance-budget.mjs";

const [contract, endpoint, client, routeError, globalError, layout, runtime] = await Promise.all([
  readFile(new URL("../app/lib/quality-observability.ts", import.meta.url), "utf8"),
  readFile(new URL("../app/api/quality/route.ts", import.meta.url), "utf8"),
  readFile(new URL("../app/components/QualitySignals.tsx", import.meta.url), "utf8"),
  readFile(new URL("../app/error.tsx", import.meta.url), "utf8"),
  readFile(new URL("../app/global-error.tsx", import.meta.url), "utf8"),
  readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
  readFile(new URL("../app/lib/runtime-config.ts", import.meta.url), "utf8"),
]);

test("kalite olayi hassas alanlari kabul etmez ve anahtarli rotalari maskeler", () => {
  assert.match(contract, /exactKeys\(value, \["schemaVersion", "kind", "name", "path", "value", "rating"\]\)/);
  assert.match(contract, /\/preview\/:token/);
  assert.match(contract, /\/copyright\/status\/:token/);
  assert.doesNotMatch(contract, /error\.message|error\.stack|referrer|userAgent|sessionId|userId/);
});

test("kalite endpointi same-origin, boyut ve fail-closed mod sinirini korur", () => {
  assert.match(endpoint, /assertSameOrigin\(request\)/);
  assert.match(endpoint, /MAX_BODY_BYTES = 2_048/);
  assert.match(endpoint, /mode === "disabled"/);
  assert.match(endpoint, /mode !== "cloudflare_logs"/);
  assert.match(endpoint, /JSON\.stringify\(event\)/);
  assert.doesNotMatch(endpoint, /JSON\.stringify\((?:request|decoded|text)\)/);
  assert.doesNotMatch(endpoint, /console\.(?:info|log|error)\([^\n]*(?:request|decoded|text)/);
  assert.match(runtime, /QUALITY_TELEMETRY_MODE/);
});

test("istemci Core Web Vitals ve genel hata sinyallerini kimliksiz gonderir", () => {
  for (const metric of ["CLS", "FCP", "INP", "LCP", "TTFB"]) assert.match(client, new RegExp(`"${metric}"`));
  assert.match(client, /globalPrivacyControl/);
  assert.match(client, /navigator\.doNotTrack === "1"/);
  assert.match(client, /credentials: "omit"/);
  assert.match(client, /\.catch\(\(\) => undefined\)/);
  assert.doesNotMatch(client, /sendBeacon/);
  assert.match(client, /unhandledrejection/);
  assert.match(layout, /<QualitySignals/);
});

test("route ve global hata ekranlari calisan kurtarma aksiyonlari sunar", () => {
  for (const source of [routeError, globalError]) {
    assert.match(source, /reportQualityEvent/);
    assert.match(source, /onClick=\{reset\}/);
    assert.match(source, /Ana sayfaya dön/);
  }
});

test("derlenmis cikti tanimli performans butcelerinin icinde kalir", () => {
  const report = checkPerformanceBudgets();
  assert.ok(report.clientJavaScript.files > 0);
  assert.ok(report.clientCss.files > 0);
  assert.ok(report.trackedPublicMedia.files > 0);
});
