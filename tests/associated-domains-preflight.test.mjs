import assert from "node:assert/strict";
import test from "node:test";
import { validateAssociatedDomainsReadiness } from "../scripts/verify-associated-domains-readiness.mjs";

const readyConfig = {
  APPLE_TEAM_ID: "ABCDE12345",
  APPLE_BUNDLE_ID: "com.panelya.panelyaMobile",
  ANDROID_PACKAGE_NAME: "com.panelya.panelya_mobile",
  ANDROID_SHA256_FINGERPRINTS:
    "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99",
};

test("Universal Links/App Links ön kontrolü tam ve biçimsel geçerli yapılandırmayı hazır sayar", () => {
  const result = validateAssociatedDomainsReadiness(readyConfig);
  assert.equal(result.ready, true);
  assert.deepEqual(result.missingEnvVars, []);
  assert.equal(result.checks.length, 4);
});

test("boş yapılandırmada eksik değişken ADLARI (değersiz) raporlanır", () => {
  const result = validateAssociatedDomainsReadiness({});
  assert.equal(result.ready, false);
  assert.deepEqual(result.missingEnvVars.sort(), [
    "ANDROID_PACKAGE_NAME",
    "ANDROID_SHA256_FINGERPRINTS",
    "APPLE_BUNDLE_ID",
    "APPLE_TEAM_ID",
  ]);
  for (const item of result.checks) {
    assert.ok(
      !JSON.stringify(item).includes("ABCDE12345"),
      "kontrol çıktısı gerçek/sentetik değer taşımamalı",
    );
  }
});

test("APPLE_TEAM_ID yanlış uzunlukta veya küçük harfliyken reddedilir (Apple Team ID her zaman 10 büyük alfanumerik karakterdir)", () => {
  const tooShort = validateAssociatedDomainsReadiness({
    ...readyConfig,
    APPLE_TEAM_ID: "ABCDE123",
  });
  assert.ok(tooShort.missingEnvVars.includes("APPLE_TEAM_ID"));

  const lowercase = validateAssociatedDomainsReadiness({
    ...readyConfig,
    APPLE_TEAM_ID: "abcde12345",
  });
  assert.ok(lowercase.missingEnvVars.includes("APPLE_TEAM_ID"));
});

test("APPLE_BUNDLE_ID / ANDROID_PACKAGE_NAME ters-DNS biçiminde olmayan (nokta içermeyen) bir değer reddedilir", () => {
  const result = validateAssociatedDomainsReadiness({
    ...readyConfig,
    APPLE_BUNDLE_ID: "panelyaMobile",
    ANDROID_PACKAGE_NAME: "panelya_mobile",
  });
  assert.ok(result.missingEnvVars.includes("APPLE_BUNDLE_ID"));
  assert.ok(result.missingEnvVars.includes("ANDROID_PACKAGE_NAME"));
});

test("ANDROID_SHA256_FINGERPRINTS içindeki HERHANGİ bir parmak izi yanlış biçimliyse tümü reddedilir", () => {
  const result = validateAssociatedDomainsReadiness({
    ...readyConfig,
    ANDROID_SHA256_FINGERPRINTS: `${readyConfig.ANDROID_SHA256_FINGERPRINTS},not-a-fingerprint`,
  });
  assert.ok(result.missingEnvVars.includes("ANDROID_SHA256_FINGERPRINTS"));
});

test("ANDROID_SHA256_FINGERPRINTS birden fazla GEÇERLİ parmak izini (virgülle ayrılmış) kabul eder", () => {
  const result = validateAssociatedDomainsReadiness({
    ...readyConfig,
    ANDROID_SHA256_FINGERPRINTS: `${readyConfig.ANDROID_SHA256_FINGERPRINTS}, ${readyConfig.ANDROID_SHA256_FINGERPRINTS}`,
  });
  assert.equal(result.ready, true);
});

test(".dev.vars eksikken tüm alanları dış kapı olarak işaretler ve secret/gerçek değer yazdırmaz", async () => {
  const { execFile } = await import("node:child_process");
  const { promisify } = await import("node:util");
  const run = promisify(execFile);
  const missingEnvFile = new URL("./fixtures/does-not-exist.dev.vars", import.meta.url).pathname;
  const { stdout } = await run("node", [
    new URL("../scripts/verify-associated-domains-readiness.mjs", import.meta.url).pathname,
    "--dev-vars",
    missingEnvFile,
  ]).catch((error) => ({ stdout: error.stdout }));
  assert.match(stdout, /bulunamadı/);
  assert.match(stdout, /APPLE_TEAM_ID/);
  assert.match(stdout, /ANDROID_SHA256_FINGERPRINTS/);
  // Çıktı yalnız değişken ADLARI ve statik açıklama taşımalı; bu test hiç
  // değer sağlamadığı için "=" işaretinden sonra bir değer görünmesi
  // beklenmez.
  assert.doesNotMatch(stdout, /=\S/);
});
