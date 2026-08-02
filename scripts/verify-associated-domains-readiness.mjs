import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import process from "node:process";
import { pathToFileURL } from "node:url";
import { parseEnvText } from "./verify-auth0-live-readiness.mjs";

// Universal Links (iOS) / App Links (Android) altyapısının prod
// deployment'ında ihtiyaç duyduğu Git dışı runtime değerlerini SADECE
// VAR/YOK (ve biçimsel geçerlilik) olarak raporlar; hiçbir gerçek değer
// stdout'a, log'a veya dosyaya yazılmaz (bkz. `app/lib/associated-domains.ts`,
// `app/well-known/apple-app-site-association/route.ts`,
// `app/well-known/assetlinks.json/route.ts`).
//
// Bu script yalnız BİÇİMSEL geçerliliği denetler (ör. Apple Team ID'nin 10
// alfanumerik karakter olması, SHA-256 parmak izinin 32 çift onaltılık
// basamak biçiminde olması) — değerlerin GERÇEKTEN Apple Developer/Play
// Console'daki kayıtlarla eşleştiğini DOĞRULAYAMAZ (bu, ilgili konsollara
// erişimi olan bir insan tarafından ayrıca teyit edilmelidir).

function check(id, ready, envVar, detail) {
  return { id, status: ready ? "ready" : "missing", envVar, detail };
}

function splitList(value) {
  return String(value ?? "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

const APPLE_TEAM_ID_PATTERN = /^[A-Z0-9]{10}$/u;
// Bundle ID / paket adı: en az iki ters-DNS segmenti (`com.panelya.panelyaMobile`
// gibi), her segment harf ile başlar.
const REVERSE_DNS_PATTERN = /^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$/u;
const SHA256_FINGERPRINT_PATTERN = /^([0-9A-Fa-f]{2}:){31}[0-9A-Fa-f]{2}$/u;

/**
 * Universal Links (iOS) / App Links (Android) production yapılandırmasının
 * hazırlığını denetler. Değer açmadan yalnız her adın var/biçimsel olarak
 * geçerli olup olmadığını döner.
 */
export function validateAssociatedDomainsReadiness(config) {
  const teamId = String(config.APPLE_TEAM_ID ?? "").trim();
  const bundleId = String(config.APPLE_BUNDLE_ID ?? "").trim();
  const packageName = String(config.ANDROID_PACKAGE_NAME ?? "").trim();
  const fingerprints = splitList(config.ANDROID_SHA256_FINGERPRINTS);

  const checks = [
    check(
      "apple-team-id",
      APPLE_TEAM_ID_PATTERN.test(teamId),
      "APPLE_TEAM_ID",
      "Apple Developer Team ID 10 alfanumerik karakter olmalı (Apple Developer hesabı -> Membership).",
    ),
    check(
      "apple-bundle-id",
      REVERSE_DNS_PATTERN.test(bundleId),
      "APPLE_BUNDLE_ID",
      "Ters-DNS biçiminde iOS bundle identifier olmalı (örn. com.ornek.uygulama); Xcode PRODUCT_BUNDLE_IDENTIFIER ile birebir eşleşmelidir.",
    ),
    check(
      "android-package-name",
      REVERSE_DNS_PATTERN.test(packageName),
      "ANDROID_PACKAGE_NAME",
      "Ters-DNS biçiminde Android applicationId olmalı; android/app/build.gradle.kts'teki applicationId ile birebir eşleşmelidir.",
    ),
    check(
      "android-sha256-fingerprints",
      fingerprints.length > 0 && fingerprints.every((fp) => SHA256_FINGERPRINT_PATTERN.test(fp)),
      "ANDROID_SHA256_FINGERPRINTS",
      "Virgülle ayrılmış bir veya daha fazla SHA-256 imza parmak izi olmalı (32 çift onaltılık basamak, iki nokta üst üste ile ayrılmış — örn. Play App Signing yükleme anahtarı + uygulama imzalama anahtarı için ayrı ayrı).",
    ),
  ];

  return {
    ready: checks.every((item) => item.status === "ready"),
    checks,
    missingEnvVars: checks
      .filter((item) => item.status === "missing")
      .map((item) => item.envVar),
  };
}

async function readConfiguration(envFile) {
  const text = await readFile(resolve(envFile), "utf8");
  return { ...parseEnvText(text), ...process.env };
}

function argumentValue(name, fallback) {
  const index = process.argv.indexOf(name);
  return index >= 0 && process.argv[index + 1] ? process.argv[index + 1] : fallback;
}

async function main() {
  // NOT: bayrak kasıtlı olarak `--env-file` DEĞİL, `--dev-vars` (bkz.
  // verify-mobile-account-live-readiness.mjs'teki aynı isimlendirme
  // gerekçesi — Node'un yerleşik `--env-file` bayrağıyla çakışmayı önler).
  const envFile = argumentValue("--dev-vars", ".dev.vars");
  let config;
  try {
    config = await readConfiguration(envFile);
  } catch {
    process.stdout.write(
      `Universal Links/App Links ön kontrolü: ${envFile} bulunamadı.\n`
      + "Dosya oluşturulmadı (Git dışı runtime dosyası kasıtlı olarak bu script tarafından yazılmaz).\n"
      + "Aşağıdaki değişken adları hiçbiri kurulu değil; production domain/Team ID/SHA-256 dış kapı kalır:\n",
    );
    const result = validateAssociatedDomainsReadiness({});
    for (const item of result.checks) {
      process.stdout.write(`EKSİK ${item.id}: ${item.envVar} — ${item.detail}\n`);
    }
    process.exitCode = 1;
    return;
  }

  const result = validateAssociatedDomainsReadiness(config);
  process.stdout.write("Universal Links (iOS) / App Links (Android) ön kontrolü\n");
  for (const item of result.checks) {
    process.stdout.write(
      `${item.status === "ready" ? "OK" : "EKSİK"} ${item.id} (${item.envVar}): ${item.detail}\n`,
    );
  }
  process.stdout.write(result.ready
    ? "SONUÇ: /.well-known/apple-app-site-association ve /.well-known/assetlinks.json production'da gerçek değerlerle sunulabilir.\n"
    : "SONUÇ: Eksik/geçersiz değerler giderilmeden bu uçlar fail-closed 503 dönmeye devam eder (bkz. app/lib/associated-domains.ts).\n");
  process.exitCode = result.ready ? 0 : 1;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  await main();
}
