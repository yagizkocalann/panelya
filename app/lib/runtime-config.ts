export async function adminBootstrapToken() {
  const nodeValue = typeof process !== "undefined" ? process.env.ADMIN_BOOTSTRAP_TOKEN : undefined;
  if (nodeValue) return nodeValue;
  try {
    const { env } = await import("cloudflare:workers");
    const workerValue = (env as unknown as Record<string, unknown>).ADMIN_BOOTSTRAP_TOKEN;
    return typeof workerValue === "string" ? workerValue : "";
  } catch {
    return "";
  }
}
