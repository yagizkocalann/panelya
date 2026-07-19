export async function runtimeValue(name: string) {
  const nodeValue = typeof process !== "undefined" ? process.env[name] : undefined;
  if (nodeValue) return nodeValue;
  try {
    const { env } = await import("cloudflare:workers");
    const workerValue = (env as unknown as Record<string, unknown>)[name];
    return typeof workerValue === "string" ? workerValue : "";
  } catch {
    return "";
  }
}

export async function adminBootstrapToken() {
  return runtimeValue("ADMIN_BOOTSTRAP_TOKEN");
}

export type NotificationDeliveryMode = "local_outbox";

export async function notificationDeliveryMode(): Promise<NotificationDeliveryMode | string> {
  return (await runtimeValue("NOTIFICATION_DELIVERY_MODE")).trim().toLowerCase() || "local_outbox";
}

export type MediaDerivativeDispatchMode = "local_browser" | "cloudflare_queue";

export async function mediaDerivativeDispatchMode(): Promise<MediaDerivativeDispatchMode | string> {
  return (await runtimeValue("MEDIA_DERIVATIVE_DISPATCH_MODE")).trim().toLowerCase() || "local_browser";
}
