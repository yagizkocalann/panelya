export const QUALITY_EVENT_SCHEMA_VERSION = "1.0" as const;

export const qualityMetricNames = ["CLS", "FCP", "INP", "LCP", "TTFB"] as const;
export type QualityMetricName = (typeof qualityMetricNames)[number];
export type QualityRating = "good" | "needs-improvement" | "poor" | "unknown";
export type QualityEventKind = "client_error" | "web_vital";

export type QualityEvent = {
  schemaVersion: typeof QUALITY_EVENT_SCHEMA_VERSION;
  kind: QualityEventKind;
  name: QualityMetricName | "global_error" | "route_error" | "unhandled_rejection";
  path: string;
  value?: number;
  rating?: QualityRating;
};

export type QualityPrivacyState = {
  globalPrivacyControl?: boolean;
  doNotTrack?: string | null;
};

const metricNames = new Set<string>(qualityMetricNames);
const errorNames = new Set(["global_error", "route_error", "unhandled_rejection"]);
const ratings = new Set<QualityRating>(["good", "needs-improvement", "poor", "unknown"]);

/**
 * Query/hash, preview anahtari ve telif takip anahtari kalite olayina girmez.
 * Public seri/bolum slug'lari urun rotasinin parcasi olarak korunabilir.
 */
export function sanitizeQualityPath(input: string) {
  const pathname = input.split(/[?#]/, 1)[0] || "/";
  if (/^\/preview\/[^/]+(?:\/.*)?$/u.test(pathname)) return "/preview/:token";
  if (/^\/copyright\/status\/[^/]+$/u.test(pathname)) return "/copyright/status/:token";
  return pathname.startsWith("/") ? pathname.slice(0, 160) || "/" : "/";
}

export function prepareQualityEvent(
  event: Omit<QualityEvent, "schemaVersion" | "path">,
  path: string,
  privacy: QualityPrivacyState,
): QualityEvent | null {
  if (privacy.globalPrivacyControl === true || privacy.doNotTrack === "1") return null;
  return {
    schemaVersion: QUALITY_EVENT_SCHEMA_VERSION,
    path: sanitizeQualityPath(path),
    ...event,
  };
}

export function qualityLogArguments(event: QualityEvent) {
  // Cloudflare Workers Logs nesne alanlarini indeksler. Bu nesne ham request,
  // exception veya serbest metin kabul etmez; parseQualityEvent allowlist'inin
  // aynisini yapisal ve sorgulanabilir bicimde tasir.
  return [{ eventType: "panelya.quality", ...event }] as const;
}

function exactKeys(value: Record<string, unknown>, allowed: readonly string[]) {
  return Object.keys(value).every((key) => allowed.includes(key));
}

export function parseQualityEvent(input: unknown): QualityEvent | null {
  if (!input || typeof input !== "object" || Array.isArray(input)) return null;
  const value = input as Record<string, unknown>;
  if (!exactKeys(value, ["schemaVersion", "kind", "name", "path", "value", "rating"])) return null;
  if (value.schemaVersion !== QUALITY_EVENT_SCHEMA_VERSION) return null;
  if (value.kind !== "client_error" && value.kind !== "web_vital") return null;
  if (typeof value.name !== "string" || typeof value.path !== "string") return null;
  if (value.path.length < 1 || value.path.length > 240) return null;

  if (value.kind === "web_vital") {
    if (!metricNames.has(value.name)) return null;
    if (typeof value.value !== "number" || !Number.isFinite(value.value) || value.value < 0 || value.value > 60_000) return null;
    if (typeof value.rating !== "string" || !ratings.has(value.rating as QualityRating)) return null;
  } else {
    if (!errorNames.has(value.name) || value.value !== undefined || value.rating !== undefined) return null;
  }

  return {
    schemaVersion: QUALITY_EVENT_SCHEMA_VERSION,
    kind: value.kind,
    name: value.name as QualityEvent["name"],
    path: sanitizeQualityPath(value.path),
    ...(value.kind === "web_vital" ? { value: value.value as number, rating: value.rating as QualityRating } : {}),
  };
}
