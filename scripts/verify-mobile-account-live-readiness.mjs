import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import process from "node:process";
import { pathToFileURL } from "node:url";
import { parseEnvText } from "./verify-auth0-live-readiness.mjs";

// Mobil hesap yonetimi (ADR-047) canli QA turu icin gereken Git disi
// runtime degerlerini SADECE VAR/YOK olarak raporlar; hicbir deger
// stdout'a, log'a veya dosyaya yazilmaz. Web BFF'e ozgu confidential
// istemci alanlari (AUTH0_WEB_CLIENT_ID/SECRET, AUTH0_WEB_REDIRECT_URIS,
// AUTH0_WEB_LOGOUT_URIS) mobil akis icin gerekmedigi icin bu kontrolde
// YER ALMAZ; web tarafinin kendi kapisi `scripts/verify-auth0-live-readiness.mjs`
// dosyasindadir.

function splitList(value) {
  return String(value ?? "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function exactUrl(value) {
  try {
    const url = new URL(value);
    return !url.username && !url.password && !url.search && !url.hash;
  } catch {
    return false;
  }
}

function check(id, ready, envVar, detail) {
  return { id, status: ready ? "ready" : "missing", envVar, detail };
}

/**
 * Mobil hesap yonetimi canli QA turunun ihtiyac duydugu Git disi runtime
 * degerlerini denetler. Deger acmadan yalniz her adin var/yeterli olup
 * olmadigini dondurur.
 */
export function validateMobileAccountLiveReadiness(config) {
  const mobileRedirectUris = splitList(config.AUTH0_MOBILE_REDIRECT_URIS);

  const checks = [
    check(
      "gateway-enabled",
      config.AUTH0_GATEWAY_ENABLED === "true",
      "AUTH0_GATEWAY_ENABLED",
      "true olmalı; aksi halde mobil token gateway'i tüm uçlarda fail-closed 503 döner.",
    ),
    check(
      "issuer",
      exactUrl(config.AUTH0_ISSUER) && new URL(config.AUTH0_ISSUER).protocol === "https:",
      "AUTH0_ISSUER",
      "Sorgu/fragment içermeyen HTTPS Auth0 tenant adresi olmalı.",
    ),
    check(
      "audience",
      exactUrl(config.AUTH0_AUDIENCE),
      "AUTH0_AUDIENCE",
      "Geçerli ve exact API audience URL'i olmalı.",
    ),
    check(
      "mobile-client",
      Boolean(config.AUTH0_MOBILE_CLIENT_ID?.trim()),
      "AUTH0_MOBILE_CLIENT_ID",
      "Native public client kimliği gerekli.",
    ),
    check(
      "mobile-callback",
      mobileRedirectUris.includes("panelya://auth/callback"),
      "AUTH0_MOBILE_REDIRECT_URIS",
      "Native callback listesinde panelya://auth/callback bulunmalı.",
    ),
    check(
      "account-runtime-secret",
      String(config.ACCOUNT_RUNTIME_SECRET ?? "").trim().length >= 32,
      "ACCOUNT_RUNTIME_SECRET",
      "En az 32 karakter olmalı; eksikse GET /api/account/sessions ve oturum kapatma uçları 503 service_unavailable döner.",
    ),
    check(
      "management-client",
      Boolean(config.AUTH0_MANAGEMENT_CLIENT_ID?.trim()),
      "AUTH0_MANAGEMENT_CLIENT_ID",
      "Management M2M client kimliği gerekli; eksikse şifre yenileme e-postası ve hesap silme 503 döner.",
    ),
    check(
      "management-secret",
      Boolean(config.AUTH0_MANAGEMENT_CLIENT_SECRET?.trim()),
      "AUTH0_MANAGEMENT_CLIENT_SECRET",
      "Management M2M client secret gerekli.",
    ),
    check(
      "management-audience",
      exactUrl(config.AUTH0_MANAGEMENT_AUDIENCE)
        && new URL(config.AUTH0_MANAGEMENT_AUDIENCE).pathname.endsWith("/api/v2/"),
      "AUTH0_MANAGEMENT_AUDIENCE",
      "HTTPS Auth0 /api/v2/ adresi olmalı.",
    ),
    check(
      "database-connection",
      Boolean(config.AUTH0_DATABASE_CONNECTION?.trim()),
      "AUTH0_DATABASE_CONNECTION",
      "Şifre yenileme e-postası isteyecek Auth0 database connection adı gerekli.",
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
  // NOT: bayrak kasıtlı olarak `--env-file` DEĞİL, `--dev-vars`. Node.js
  // 20.6+ kendi yerleşik `--env-file` bayrağını script argv'sinde NEREDE
  // olursa olsun tüketir; hedef dosya yoksa Node, script hiç çalışmadan
  // kendi opak "not found" hatasıyla (exit 9) çöker ve aşağıdaki dostane
  // "bulunamadı" mesajı hiç basılmaz. Bu çakışma bu scriptte `--dev-vars`
  // kullanılarak önlenmiştir.
  const envFile = argumentValue("--dev-vars", ".dev.vars");
  let config;
  try {
    config = await readConfiguration(envFile);
  } catch {
    process.stdout.write(
      `Mobil hesap yönetimi canlı ön kontrolü: ${envFile} bulunamadı.\n`
      + "Dosya oluşturulmadı (Git dışı runtime dosyası kasıtlı olarak bu script tarafından yazılmaz).\n"
      + "Aşağıdaki değişken adları hiçbiri kurulu değil, ilgili akışlar 'dış kapı' kalır:\n",
    );
    const placeholderConfig = {};
    const result = validateMobileAccountLiveReadiness(placeholderConfig);
    for (const item of result.checks) {
      process.stdout.write(`EKSİK ${item.id}: ${item.envVar} — ${item.detail}\n`);
    }
    process.exitCode = 1;
    return;
  }

  const result = validateMobileAccountLiveReadiness(config);
  process.stdout.write("Mobil hesap yönetimi canlı ön kontrolü\n");
  for (const item of result.checks) {
    process.stdout.write(
      `${item.status === "ready" ? "OK" : "EKSİK"} ${item.id} (${item.envVar}): ${item.detail}\n`,
    );
  }
  process.stdout.write(result.ready
    ? "SONUÇ: Mobil hesap yönetimi canlı QA turuna hazır.\n"
    : `SONUÇ: Eksik değişkenler: ${result.missingEnvVars.join(", ")}. Bunlar giderilmeden ilgili akışlar dış kapı kalır.\n`);
  process.exitCode = result.ready ? 0 : 1;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  await main();
}
