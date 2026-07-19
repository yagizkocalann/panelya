export type AdRuntimeMode = "disabled" | "google_test";

function hostnameFromHostHeader(host: string) {
  const normalized = host.trim().toLowerCase();
  if (normalized.startsWith("http://") || normalized.startsWith("https://")) return new URL(normalized).hostname;
  if (normalized.startsWith("[")) return normalized.slice(0, normalized.indexOf("]") + 1);
  return normalized.split(":")[0];
}

export function isLocalAdHost(host: string) {
  const hostname = hostnameFromHostHeader(host);
  return hostname === "localhost" || hostname.endsWith(".localhost") || hostname === "127.0.0.1" || hostname === "[::1]";
}

export function resolveAdRuntimeMode(host: string, configuredMode = process.env.AD_RUNTIME_MODE): AdRuntimeMode {
  const mode = configuredMode?.trim().toLowerCase();
  if (mode === "disabled") return "disabled";
  if ((mode === undefined || mode === "" || mode === "google_test") && isLocalAdHost(host)) return "google_test";

  // Production reklam kimlikleri bu sinira bilerek baglanmadi. Bilinmeyen,
  // production veya localhost disindaki test modlari harici istek yapmadan kapanir.
  return "disabled";
}
