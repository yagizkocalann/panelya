import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import process from "node:process";
import { pathToFileURL } from "node:url";
import {
  parseEnvText,
  validateAuth0LiveReadiness,
} from "./verify-auth0-live-readiness.mjs";

function check(id, ready, detail) {
  return { id, status: ready ? "ready" : "missing", detail };
}

function exactHttpsOrigin(value) {
  try {
    const url = new URL(String(value ?? ""));
    const hostname = url.hostname.toLowerCase();
    const local = hostname === "localhost"
      || hostname.endsWith(".localhost")
      || hostname === "127.0.0.1"
      || hostname === "::1";
    return url.protocol === "https:"
      && url.pathname === "/"
      && !url.username
      && !url.password
      && !url.search
      && !url.hash
      && !local
      ? url.origin
      : "";
  } catch {
    return "";
  }
}

function pushConfigurationReady(config) {
  const mode = String(config.PUSH_DELIVERY_MODE ?? "disabled").trim().toLowerCase();
  if (mode === "disabled") return true;
  return mode === "fcm"
    && Boolean(config.FCM_PROJECT_ID?.trim())
    && Boolean(config.FCM_CLIENT_EMAIL?.trim())
    && Boolean(config.FCM_PRIVATE_KEY?.trim());
}

export function validateProductionDeploymentReadiness(config) {
  const publicOrigin = exactHttpsOrigin(config.PUBLIC_SITE_ORIGIN);
  const studioOrigin = exactHttpsOrigin(config.STUDIO_SITE_ORIGIN);
  const expectedStudioOrigin = publicOrigin
    ? `https://studio.${new URL(publicOrigin).hostname}`
    : "";
  const auth0 = validateAuth0LiveReadiness(config, publicOrigin || "invalid");

  const checks = [
    check(
      "public-origin",
      Boolean(publicOrigin),
      "PUBLIC_SITE_ORIGIN localhost olmayan exact HTTPS origin olmalı.",
    ),
    check(
      "studio-origin",
      Boolean(studioOrigin) && studioOrigin === expectedStudioOrigin,
      "STUDIO_SITE_ORIGIN exact https://studio.<public-host> biçiminde olmalı.",
    ),
    check(
      "dummy-catalog-disabled",
      String(config.LOCAL_DUMMY_CATALOG ?? "").trim().toLowerCase() === "false",
      "LOCAL_DUMMY_CATALOG production için açıkça false olmalı.",
    ),
    check(
      "media-mode",
      String(config.MEDIA_DERIVATIVE_DISPATCH_MODE ?? "").trim().toLowerCase() === "cloudflare_queue",
      "Responsive medya dağıtımı cloudflare_queue olmalı.",
    ),
    check(
      "rate-limit-mode",
      String(config.RATE_LIMIT_MODE ?? "").trim().toLowerCase() === "cloudflare_hybrid",
      "Production rate-limit modu cloudflare_hybrid olmalı.",
    ),
    check(
      "quality-telemetry",
      String(config.QUALITY_TELEMETRY_MODE ?? "").trim().toLowerCase() === "cloudflare_logs",
      "Gizlilik onaylı production kalite modu cloudflare_logs olmalı.",
    ),
    check(
      "ads-disabled",
      String(config.AD_RUNTIME_MODE ?? "").trim().toLowerCase() === "disabled",
      "Gerçek reklam sözleşmesi gelene kadar AD_RUNTIME_MODE disabled olmalı.",
    ),
    check(
      "admin-bootstrap",
      String(config.ADMIN_BOOTSTRAP_TOKEN ?? "").trim().length >= 32,
      "İlk Studio yöneticisi için en az 32 karakterlik bootstrap sırrı gerekli.",
    ),
    check(
      "push-mode",
      pushConfigurationReady(config),
      "Push disabled kalabilir; fcm seçilirse üç sunucu yapılandırması da bulunmalı.",
    ),
    check(
      "notification-outbox",
      String(config.NOTIFICATION_DELIVERY_MODE ?? "local_outbox").trim().toLowerCase() === "local_outbox",
      "Harici e-posta sağlayıcısı gelene kadar local_outbox açıkça korunmalı.",
    ),
    ...auth0.checks.map((item) => ({
      ...item,
      id: `auth0-${item.id}`,
    })),
  ];

  return {
    ready: checks.every((item) => item.status === "ready"),
    checks,
    manualCloudflareChecks: [
      "D1 DB ve R2 MEDIA binding'leri",
      "IMAGES binding'i",
      "MEDIA_DERIVATIVE_QUEUE producer + consumer + ayrı DLQ",
      "EDGE_RATE_LIMITER binding'i ve hesap namespace'i",
      "studio.<public-host> DNS/TLS yönlendirmesi",
    ],
  };
}

function argumentValue(name, fallback) {
  const index = process.argv.indexOf(name);
  return index >= 0 && process.argv[index + 1] ? process.argv[index + 1] : fallback;
}

async function main() {
  const envFile = argumentValue("--env-file", ".dev.vars");
  let config;
  try {
    const text = await readFile(resolve(envFile), "utf8");
    config = { ...parseEnvText(text), ...process.env };
  } catch {
    process.stderr.write(`Production ön kontrolü: ${envFile} okunamadı.\n`);
    process.exitCode = 1;
    return;
  }

  const result = validateProductionDeploymentReadiness(config);
  process.stdout.write("Panelya production runtime ön kontrolü\n");
  for (const item of result.checks) {
    process.stdout.write(`${item.status === "ready" ? "OK" : "EKSİK"} ${item.id}: ${item.detail}\n`);
  }
  process.stdout.write("Elle doğrulanacak Cloudflare kaynakları:\n");
  for (const detail of result.manualCloudflareChecks) process.stdout.write(`- ${detail}\n`);
  process.stdout.write(result.ready
    ? "SONUÇ: Runtime değerleri hazır; Cloudflare kaynakları canlı readiness ucuyla ayrıca doğrulanmalı.\n"
    : "SONUÇ: Eksikler giderilmeden production sürümü kaydedilmemeli veya deploy edilmemeli.\n");
  process.exitCode = result.ready ? 0 : 1;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  await main();
}
