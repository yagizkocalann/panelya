import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import test from "node:test";
import {
  IOS_PUSH_EXTERNAL_DEPENDENCIES,
  validateIosPushReadiness,
} from "../scripts/verify-ios-push-readiness.mjs";

// Bu dosya gerçek bir Xcode build/APNs kaydı ÇALIŞTIRMAZ (bkz.
// docs/mobile-web-handoff-findings.md #5 — Simulator APNs token alamaz,
// bu yalnız fiziksel cihazda canlı doğrulanabilir). Yalnız
// `verify-ios-push-readiness.mjs`nin statik dosya denetimini, sabit
// fixture proje ağaçlarına karşı test eder.

const readyRoot = new URL("./fixtures/ios-push-ready/", import.meta.url);
const missingRoot = new URL("./fixtures/ios-push-missing/", import.meta.url);
const entitlementsWithoutApsRoot = new URL(
  "./fixtures/ios-push-entitlements-without-aps/",
  import.meta.url,
);
const realMobileRoot = new URL("../apps/mobile/", import.meta.url);

test("tüm parçalar hazırsa (entitlements + wiring + Firebase dosyası + url scheme + background mode) ready true döner", async () => {
  const result = await validateIosPushReadiness({ mobileRoot: readyRoot });
  assert.equal(result.ready, true);
  assert.deepEqual(result.missingBlocking, []);
  assert.ok(result.checks.every((item) => item.status === "ready"));
});

test("entitlements dosyası, wiring ve Firebase dosyası eksikken BLOKE EDİCİ eksikler doğru raporlanır", async () => {
  const result = await validateIosPushReadiness({ mobileRoot: missingRoot });
  assert.equal(result.ready, false);
  assert.deepEqual(result.missingBlocking.sort(), [
    "entitlements-file",
    "entitlements-wired-to-target",
    "google-service-plist-present",
    "url-scheme",
  ]);
});

test("Runner.entitlements VAR ama içinde 'aps-environment' anahtarı YOKSA (örn. yalnız Universal Links "
  + "associated-domains için oluşturulmuş bir dosya) 'entitlements-file' kontrolü yine de MISSING raporlar "
  + "— dosyanın salt VARLIĞI push readiness'i için yeterli bir sinyal değildir", async () => {
  const result = await validateIosPushReadiness({
    mobileRoot: entitlementsWithoutApsRoot,
  });
  const entitlementsCheck = result.checks.find((item) => item.id === "entitlements-file");
  assert.ok(entitlementsCheck);
  assert.equal(entitlementsCheck.status, "missing");
  assert.equal(result.ready, false);
  assert.ok(result.missingBlocking.includes("entitlements-file"));
  // Diğer bloke ediciler bu fixture'da HAZIR — yalnız aps-environment eksik.
  assert.ok(!result.missingBlocking.includes("url-scheme"));
  assert.ok(!result.missingBlocking.includes("entitlements-wired-to-target"));
  assert.ok(!result.missingBlocking.includes("google-service-plist-present"));
});

test("UIBackgroundModes/remote-notification eksik olması TEK BAŞINA genel sonucu FAIL yapmaz (bilgilendirici, bloke edici değil)", async () => {
  // ready fixture'ı zaten remote-notification'ı İÇERİYOR; burada yalnız bu
  // KONTROLÜN blocking:false olarak işaretlendiğini ve missing olsa bile
  // ready'i tek başına düşürmediğini doğruluyoruz (missing fixture'da hem
  // background hem başka bloke ediciler eksik olduğu için orada izole
  // edilemez).
  const result = await validateIosPushReadiness({ mobileRoot: readyRoot });
  const backgroundCheck = result.checks.find(
    (item) => item.id === "background-remote-notification",
  );
  assert.ok(backgroundCheck);
  assert.equal(backgroundCheck.blocking, false);
});

test("dış bağımlılık listesi yalnız ADLAR taşır — hiçbir kontrol çıktısı secret/gerçek değer İÇERMEZ", async () => {
  const result = await validateIosPushReadiness({ mobileRoot: missingRoot });
  const serialized = JSON.stringify(result) + JSON.stringify(IOS_PUSH_EXTERNAL_DEPENDENCIES);
  // Fixture'lardaki sahte takım kimliği bile çıktıya sızmamalı.
  assert.doesNotMatch(serialized, /FIXTUREZZZZ/);
  assert.ok(IOS_PUSH_EXTERNAL_DEPENDENCIES.length >= 5);
  assert.ok(
    IOS_PUSH_EXTERNAL_DEPENDENCIES.some((name) => name.includes("Apple Developer")),
  );
  assert.ok(
    IOS_PUSH_EXTERNAL_DEPENDENCIES.some((name) => name.includes("Simulator")),
  );
});

test("CLI çıktısı hiçbir dosya içeriğini/secret değeri yazdırmaz (yalnız var/yok + sabit açıklama)", async () => {
  const { execFile } = await import("node:child_process");
  const { promisify } = await import("node:util");
  const run = promisify(execFile);
  const scriptPath = fileURLToPath(
    new URL("../scripts/verify-ios-push-readiness.mjs", import.meta.url),
  );
  const { stdout } = await run(process.execPath, [scriptPath]).catch((error) => ({
    stdout: error.stdout,
  }));
  assert.match(stdout, /iOS push canlı ön kontrolü/);
  assert.match(stdout, /Dış bağımlılıklar|dış bağımlılıklar/);
  // FCM gönderim değişkenlerinin başka bir script tarafından ZATEN
  // denetlendiği belirtilir ama DEĞER asla yazdırılmaz.
  assert.doesNotMatch(stdout, /-----BEGIN/);
});

test("gerçek apps/mobile proje ağacına karşı çalışır ve atmaz (regex/parsing gerçek dosya biçimiyle uyumlu)", async () => {
  const result = await validateIosPushReadiness({ mobileRoot: realMobileRoot });
  assert.equal(result.checks.length, 5);
  // Gerçek Info.plist'te panelya:// şeması zaten kayıtlı (bkz.
  // apps/mobile/ios/Runner/Info.plist CFBundleURLSchemes).
  const urlSchemeCheck = result.checks.find((item) => item.id === "url-scheme");
  assert.equal(urlSchemeCheck.status, "ready");
});
