import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import ts from "typescript";
import { checkPerformanceBudgets } from "../scripts/check-performance-budget.mjs";

const [contract, endpoint, client, routeError, globalError, layout, runtime, viteConfig, registerRoute] = await Promise.all([
  readFile(new URL("../app/lib/quality-observability.ts", import.meta.url), "utf8"),
  readFile(new URL("../app/api/quality/route.ts", import.meta.url), "utf8"),
  readFile(new URL("../app/components/QualitySignals.tsx", import.meta.url), "utf8"),
  readFile(new URL("../app/error.tsx", import.meta.url), "utf8"),
  readFile(new URL("../app/global-error.tsx", import.meta.url), "utf8"),
  readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
  readFile(new URL("../app/lib/runtime-config.ts", import.meta.url), "utf8"),
  readFile(new URL("../vite.config.ts", import.meta.url), "utf8"),
  readFile(new URL("../app/api/auth/register/route.ts", import.meta.url), "utf8"),
]);

const executableContract = ts.transpileModule(contract, {
  compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 },
}).outputText;
const contractModule = await import(`data:text/javascript;base64,${Buffer.from(executableContract).toString("base64")}`);

test("kalite olayi hassas alanlari kabul etmez ve anahtarli rotalari maskeler", () => {
  assert.match(contract, /exactKeys\(value, \["schemaVersion", "kind", "name", "path", "value", "rating"\]\)/);
  assert.match(contract, /\/preview\/:token/);
  assert.match(contract, /\/copyright\/status\/:token/);
  assert.doesNotMatch(contract, /error\.message|error\.stack|referrer|userAgent|sessionId|userId/);
});

test("GPC ve DNT kalite govdesini olusmadan durdurur", () => {
  const event = { kind: "client_error", name: "global_error" };
  assert.equal(contractModule.prepareQualityEvent(event, "/catalog", { globalPrivacyControl: true }), null);
  assert.equal(contractModule.prepareQualityEvent(event, "/catalog", { doNotTrack: "1" }), null);
  assert.deepEqual(
    contractModule.prepareQualityEvent(event, "/preview/secret-value?query=ignored", {}),
    { schemaVersion: "1.0", kind: "client_error", name: "global_error", path: "/preview/:token" },
  );
});

test("Cloudflare log satiri yalniz sanitize edilmis allowlist olayini tasir", () => {
  const event = contractModule.prepareQualityEvent(
    { kind: "client_error", name: "global_error" },
    "/preview/qa-only-token?email=ignored@example.invalid#fragment",
    {},
  );
  assert.deepEqual(contractModule.qualityLogArguments(event), [{
    eventType: "panelya.quality",
    schemaVersion: "1.0",
    path: "/preview/:token",
    kind: "client_error",
    name: "global_error",
  }]);
  const serialized = JSON.stringify(contractModule.qualityLogArguments(event));
  assert.doesNotMatch(serialized, /qa-only-token|ignored@example\.invalid|fragment|message|stack|session|userAgent|referrer/);
});

test("Cloudflare otomatik invocation metadata'sini ve ham auth exception'ini saklamaz", () => {
  assert.match(viteConfig, /observability:\s*\{/);
  assert.match(viteConfig, /invocation_logs:\s*false/);
  assert.match(viteConfig, /head_sampling_rate:\s*1/);
  assert.match(registerRoute, /errorType: error instanceof Error \? "exception" : "unknown"/);
  assert.doesNotMatch(registerRoute, /error\.name/);
  assert.doesNotMatch(registerRoute, /console\.error\("register_failed", error\)/);
});

test("kalite endpointi same-origin, boyut ve fail-closed mod sinirini korur", () => {
  assert.match(endpoint, /assertSameOrigin\(request\)/);
  assert.match(endpoint, /MAX_BODY_BYTES = 2_048/);
  assert.match(endpoint, /mode === "disabled"/);
  assert.match(endpoint, /mode !== "cloudflare_logs"/);
  assert.match(endpoint, /qualityLogArguments\(event\)/);
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
