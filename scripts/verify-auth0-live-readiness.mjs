import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import process from "node:process";
import { pathToFileURL } from "node:url";

const REQUIRED_MANAGEMENT_SCOPES = [
  "read:users",
  "update:users",
  "delete:users",
  "read:device_credentials",
  "delete:device_credentials",
];

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

function check(id, ready, detail) {
  return { id, status: ready ? "ready" : "missing", detail };
}

export function parseEnvText(text) {
  const values = {};
  for (const rawLine of text.split(/\r?\n/u)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const match = /^(?:export\s+)?([A-Z][A-Z0-9_]*)\s*=\s*(.*)$/u.exec(line);
    if (!match) continue;
    let value = match[2].trim();
    if ((value.startsWith("\"") && value.endsWith("\""))
      || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    values[match[1]] = value;
  }
  return values;
}

export function validateAuth0LiveReadiness(config, publicOriginValue) {
  let publicOrigin;
  try {
    const parsed = new URL(publicOriginValue);
    publicOrigin = parsed.origin;
  } catch {
    publicOrigin = "";
  }

  const webRedirectUris = splitList(config.AUTH0_WEB_REDIRECT_URIS);
  const webLogoutUris = splitList(config.AUTH0_WEB_LOGOUT_URIS);
  const mobileRedirectUris = splitList(config.AUTH0_MOBILE_REDIRECT_URIS);
  const expectedWebCallbacks = publicOrigin
    ? [
        `${publicOrigin}/api/auth/web/callback`,
        `${publicOrigin}/account/reauthentication/callback`,
      ]
    : [];

  const checks = [
    check(
      "gateway-enabled",
      config.AUTH0_GATEWAY_ENABLED === "true",
      "AUTH0_GATEWAY_ENABLED true olmalı.",
    ),
    check(
      "issuer",
      exactUrl(config.AUTH0_ISSUER) && new URL(config.AUTH0_ISSUER).protocol === "https:",
      "AUTH0_ISSUER sorgu veya fragment içermeyen HTTPS adresi olmalı.",
    ),
    check("audience", exactUrl(config.AUTH0_AUDIENCE), "AUTH0_AUDIENCE geçerli ve exact olmalı."),
    check("mobile-client", Boolean(config.AUTH0_MOBILE_CLIENT_ID?.trim()), "Native public client kimliği gerekli."),
    check(
      "mobile-callback",
      mobileRedirectUris.includes("panelya://auth/callback"),
      "Native callback listesinde panelya://auth/callback bulunmalı.",
    ),
    check("web-client", Boolean(config.AUTH0_WEB_CLIENT_ID?.trim()), "Confidential web client kimliği gerekli."),
    check("web-secret", Boolean(config.AUTH0_WEB_CLIENT_SECRET?.trim()), "Confidential web client secret gerekli."),
    check(
      "web-callbacks",
      expectedWebCallbacks.length === 2
        && expectedWebCallbacks.every((callback) => webRedirectUris.includes(callback)),
      "Normal giriş ve hesap yeniden doğrulama callback adresleri exact allowlist'te olmalı.",
    ),
    check(
      "web-logout",
      Boolean(publicOrigin) && webLogoutUris.includes(publicOrigin),
      "Public origin exact logout allowlist'inde olmalı.",
    ),
    check(
      "management-client",
      Boolean(config.AUTH0_MANAGEMENT_CLIENT_ID?.trim()),
      "Management M2M client kimliği gerekli.",
    ),
    check(
      "management-secret",
      Boolean(config.AUTH0_MANAGEMENT_CLIENT_SECRET?.trim()),
      "Management M2M client secret gerekli.",
    ),
    check(
      "management-audience",
      exactUrl(config.AUTH0_MANAGEMENT_AUDIENCE)
        && new URL(config.AUTH0_MANAGEMENT_AUDIENCE).pathname.endsWith("/api/v2/"),
      "Management audience HTTPS Auth0 /api/v2/ adresi olmalı.",
    ),
    check(
      "database-connection",
      Boolean(config.AUTH0_DATABASE_CONNECTION?.trim()),
      "Auth0 database connection adı gerekli.",
    ),
    check(
      "account-runtime-secret",
      String(config.ACCOUNT_RUNTIME_SECRET ?? "").trim().length >= 32,
      "ACCOUNT_RUNTIME_SECRET en az 32 karakter olmalı.",
    ),
  ];

  return {
    ready: checks.every((item) => item.status === "ready"),
    publicOrigin: publicOrigin || "invalid",
    checks,
    requiredManagementScopes: [...REQUIRED_MANAGEMENT_SCOPES],
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
  const envFile = argumentValue("--env-file", ".dev.vars");
  let config;
  try {
    config = await readConfiguration(envFile);
  } catch {
    process.stderr.write(`Auth0 ön kontrolü: ${envFile} okunamadı.\n`);
    process.exitCode = 1;
    return;
  }
  const publicOrigin = argumentValue(
    "--origin",
    config.PUBLIC_SITE_ORIGIN || "http://localhost:3000",
  );
  const result = validateAuth0LiveReadiness(config, publicOrigin);

  process.stdout.write("Auth0 canlı hazırlık kontrolü\n");
  for (const item of result.checks) {
    process.stdout.write(`${item.status === "ready" ? "OK" : "EKSİK"} ${item.id}: ${item.detail}\n`);
  }
  process.stdout.write(`Gerekli Management API izinleri: ${result.requiredManagementScopes.join(", ")}\n`);
  process.stdout.write(result.ready
    ? "SONUÇ: Yapılandırma canlı smoke testine hazır.\n"
    : "SONUÇ: Eksikler giderilmeden canlı smoke testi başlatılmamalı.\n");
  process.exitCode = result.ready ? 0 : 1;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  await main();
}
