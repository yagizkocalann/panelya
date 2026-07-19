import { MEDIA_DERIVATIVE_QUEUE_BINDING } from "./media/derivative-dispatch";
import { EDGE_RATE_LIMITER_BINDING } from "./rate-limit";
import { mediaDerivativeDispatchMode, rateLimitMode } from "./runtime-config";

export const PLATFORM_READINESS_SCHEMA_VERSION = "1.0" as const;

export type PlatformProfile = "local" | "production" | "mixed";
export type PlatformCheckStatus = "ready" | "missing" | "not_required" | "manual" | "misconfigured";
type SafeMediaMode = "local_browser" | "cloudflare_queue" | "invalid";
type SafeRateLimitMode = "d1_strict" | "cloudflare_hybrid" | "invalid";

export type PlatformReadinessCheck = {
  id: string;
  label: string;
  status: PlatformCheckStatus;
  required: boolean;
  detail: string;
};

type RuntimeBindingMap = Record<string, unknown>;

function hasMethod(bindings: RuntimeBindingMap, binding: string, method: string) {
  const value = bindings[binding];
  return Boolean(value && typeof value === "object" && typeof (value as Record<string, unknown>)[method] === "function");
}

function bindingCheck(id: string, label: string, available: boolean, required: boolean, detail: string): PlatformReadinessCheck {
  return { id, label, required, detail, status: available ? "ready" : required ? "missing" : "not_required" };
}

export function assessPlatformReadiness(input: {
  mediaMode: string;
  rateLimitMode: string;
  bindings: RuntimeBindingMap;
}) {
  const mediaMode: SafeMediaMode = input.mediaMode === "local_browser" || input.mediaMode === "cloudflare_queue" ? input.mediaMode : "invalid";
  const configuredRateLimitMode: SafeRateLimitMode = input.rateLimitMode === "d1_strict" || input.rateLimitMode === "cloudflare_hybrid" ? input.rateLimitMode : "invalid";
  const localModes = mediaMode === "local_browser" && configuredRateLimitMode === "d1_strict";
  const productionModes = mediaMode === "cloudflare_queue" && configuredRateLimitMode === "cloudflare_hybrid";
  const profile: PlatformProfile = localModes ? "local" : productionModes ? "production" : "mixed";
  const queueRequired = mediaMode === "cloudflare_queue";
  const edgeRequired = configuredRateLimitMode === "cloudflare_hybrid";

  const checks: PlatformReadinessCheck[] = [
    bindingCheck("binding-db", "D1 veritabanı", hasMethod(input.bindings, "DB", "prepare"), true, "Kalıcı katalog, hesap ve iş durumunun kaynağı."),
    bindingCheck("binding-media", "R2 medya deposu", hasMethod(input.bindings, "MEDIA", "get") && hasMethod(input.bindings, "MEDIA", "put"), true, "Kaynak ve türetilmiş medya nesnelerini saklar."),
    bindingCheck("binding-images", "Cloudflare Images", hasMethod(input.bindings, "IMAGES", "input"), queueRequired, "Production consumer WebP varyantını dönüştürür."),
    bindingCheck("binding-queue", MEDIA_DERIVATIVE_QUEUE_BINDING, hasMethod(input.bindings, MEDIA_DERIVATIVE_QUEUE_BINDING, "send"), queueRequired, "Responsive medya görevlerini Queue consumer'a teslim eder."),
    bindingCheck("binding-rate-limit", EDGE_RATE_LIMITER_BINDING, hasMethod(input.bindings, EDGE_RATE_LIMITER_BINDING, "limit"), edgeRequired, "Ani trafik kalkanını D1 kesin kotasının önünde uygular."),
    {
      id: "mode-pair",
      label: "Runtime mod çifti",
      required: true,
      status: profile === "mixed" ? "misconfigured" : "ready",
      detail: profile === "mixed"
        ? "Medya ve rate-limit modları aynı local veya production profilinde değil."
        : profile === "production"
          ? "cloudflare_queue + cloudflare_hybrid"
          : "local_browser + d1_strict",
    },
    {
      id: "queue-consumer-dlq",
      label: "Queue consumer ve dead-letter kuyruğu",
      required: profile === "production",
      status: profile === "production" ? "manual" : "not_required",
      detail: "Runtime binding nesnesi consumer retry/DLQ politikasını açıklamaz; deployment kaynağında ayrıca doğrulanır.",
    },
  ];

  const automatedReady = profile !== "mixed"
    && checks.filter((check) => check.required && check.status !== "manual").every((check) => check.status === "ready");

  return {
    schemaVersion: PLATFORM_READINESS_SCHEMA_VERSION,
    profile,
    automatedReady,
    manualVerificationRequired: checks.some((check) => check.required && check.status === "manual"),
    modes: { media: mediaMode, rateLimit: configuredRateLimitMode },
    checks,
  } as const;
}

export async function getPlatformReadiness() {
  const [mediaMode, configuredRateLimitMode] = await Promise.all([mediaDerivativeDispatchMode(), rateLimitMode()]);
  try {
    const { env } = await import("cloudflare:workers");
    return assessPlatformReadiness({ mediaMode, rateLimitMode: configuredRateLimitMode, bindings: env as unknown as RuntimeBindingMap });
  } catch {
    return assessPlatformReadiness({ mediaMode, rateLimitMode: configuredRateLimitMode, bindings: {} });
  }
}
