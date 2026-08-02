import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

// Bu dosya gerçek bir Android keystore/Gradle çalıştırması GEREKTİRMEZ; yalnız
// `apps/mobile/android/app/build.gradle.kts` içindeki release imzalama
// mantığını statik metin olarak denetler. Amaç: production imzasının Git
// dışı kaynaklardan (key.properties veya ortam değişkenleri) geldiğini,
// eksik değerlerde release build'in debug anahtarına SESSİZCE düşmediğini
// ve açık bir hata ile durduğunu, debug build'in ise etkilenmediğini
// garanti altına almak. Bkz. docs/mobile-web-handoff-findings.md #7 ve
// apps/mobile/README.md "Release build".

const [gradleFile, rootGitignore, androidGitignore] = await Promise.all([
  readFile(new URL("../apps/mobile/android/app/build.gradle.kts", import.meta.url), "utf8"),
  readFile(new URL("../.gitignore", import.meta.url), "utf8"),
  readFile(new URL("../apps/mobile/android/.gitignore", import.meta.url), "utf8"),
]);

test("release build type debug signingConfig'e düşmez", () => {
  assert.doesNotMatch(
    gradleFile,
    /signingConfig\s*=\s*signingConfigs\.getByName\(\s*"debug"\s*\)/u,
    "release buildType hâlâ debug anahtarıyla imzalanıyor gibi görünüyor",
  );
  // Geriye kalan tek TODO'nun bu satırlarla ilgili olmadığından emin ol.
  assert.doesNotMatch(gradleFile, /Signing with the debug keys/iu);
});

test("release imzası key.properties ve PANELYA_ANDROID_* ortam değişkenlerinden okunur, öncelik key.properties'tedir", () => {
  assert.match(gradleFile, /rootProject\.file\(\s*"key\.properties"\s*\)/u);
  for (const envKey of [
    "PANELYA_ANDROID_KEYSTORE_PATH",
    "PANELYA_ANDROID_KEYSTORE_PASSWORD",
    "PANELYA_ANDROID_KEY_ALIAS",
    "PANELYA_ANDROID_KEY_PASSWORD",
  ]) {
    assert.match(gradleFile, new RegExp(`System\\.getenv\\(\\s*"${envKey}"\\s*\\)|releaseSigningValue\\([^)]*"${envKey}"`, "u"));
  }
  // fonksiyon önce dosyadan gelen değeri döndürür, yalnız o boşsa env'e düşer.
  const fnMatch = gradleFile.match(/fun releaseSigningValue[\s\S]*?\n\}/u);
  assert.ok(fnMatch, "releaseSigningValue fonksiyonu bulunamadı");
  assert.match(fnMatch[0], /keystoreProperties\.getProperty/u);
  assert.match(fnMatch[0], /System\.getenv/u);
  assert.ok(
    fnMatch[0].indexOf("keystoreProperties.getProperty") < fnMatch[0].indexOf("System.getenv"),
    "key.properties, ortam değişkeninden önce okunmalı (dokümante edilen öncelik sırası)",
  );
});

test("eksik release imza değeri açık bir hata fırlatır ve hiçbir değeri yazdırmaz", () => {
  assert.match(gradleFile, /throw GradleException/u);
  assert.match(gradleFile, /missingReleaseSigningKeys/u);
  // Hata mesajı yalnız hangi property/env adının eksik olduğunu söyler;
  // gerçek bir değer (parola, yol, alias) literal olarak asla yazılmaz.
  const exceptionMatch = gradleFile.match(/throw GradleException\(\s*([\s\S]*?)\)\s*\n\}/u);
  assert.ok(exceptionMatch, "GradleException mesaj gövdesi bulunamadı");
  assert.doesNotMatch(exceptionMatch[1], /storePassword\s*=|keyPassword\s*=|releaseStorePassword!!|releaseKeyPassword!!/u);
});

test("fail-closed kontrolü yalnız release görevleri çalıştırılırken tetiklenir (debug build etkilenmez)", () => {
  assert.match(gradleFile, /gradle\.startParameter\.taskNames/u);
  assert.match(gradleFile, /contains\(\s*"Release"/iu);
  assert.match(gradleFile, /isRunningReleaseTask\s*&&\s*missingReleaseSigningKeys\.isNotEmpty\(\)/u);
});

test("signingConfigs.release nesnesi debug derlemede de güvenle oluşturulur (eksik değerlerle crash olmaz)", () => {
  assert.match(gradleFile, /create\(\s*"release"\s*\)\s*\{/u);
  assert.match(gradleFile, /if\s*\(missingReleaseSigningKeys\.isEmpty\(\)\)\s*\{/u);
});

test("key.properties ve keystore dosya desenleri .gitignore'da", () => {
  assert.match(rootGitignore, /key\.properties/u);
  assert.match(rootGitignore, /\*\.keystore/u);
  assert.match(rootGitignore, /\*\.jks/u);
  assert.match(androidGitignore, /^key\.properties$/mu);
  assert.match(androidGitignore, /\*\*\/\*\.keystore/u);
  assert.match(androidGitignore, /\*\*\/\*\.jks/u);
});
