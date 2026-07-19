import { hashOpaqueToken } from "./auth";
import { getDatabase } from "./database";
import { rateLimitMode, type RateLimitMode } from "./runtime-config";

export const EDGE_RATE_LIMITER_BINDING = "EDGE_RATE_LIMITER" as const;
const SHA256_BASE64_PATTERN = /^[A-Za-z0-9+/]{43}=$/;

type EdgeRateLimiter = {
  limit(input: { key: string }): Promise<{ success: boolean }>;
};

type RateLimitAdapter = {
  mode: RateLimitMode;
  edgeEnabled: boolean;
  consumeEdge(key: string): Promise<boolean>;
};

export async function requestFingerprint(request: Request, value: string) {
  const client = request.headers.get("cf-connecting-ip") ?? request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "local";
  return hashOpaqueToken(`${client}:${value.trim().toLowerCase()}`);
}

export function createRateLimitAdapter(mode: string, edge?: EdgeRateLimiter): RateLimitAdapter {
  if (mode === "d1_strict") {
    return { mode, edgeEnabled: false, async consumeEdge() { return true; } };
  }
  if (mode === "cloudflare_hybrid") {
    if (!edge || typeof edge.limit !== "function") throw new Error(`${EDGE_RATE_LIMITER_BINDING} binding is unavailable.`);
    return {
      mode,
      edgeEnabled: true,
      async consumeEdge(key) {
        const result = await edge.limit({ key });
        return result.success;
      },
    };
  }
  throw new Error("Unsupported rate limit mode.");
}

async function getRateLimitAdapter() {
  const mode = await rateLimitMode();
  if (mode === "d1_strict") return createRateLimitAdapter(mode);
  if (mode !== "cloudflare_hybrid") return createRateLimitAdapter(mode);
  const { env } = await import("cloudflare:workers");
  const edge = (env as unknown as Record<string, unknown>)[EDGE_RATE_LIMITER_BINDING] as EdgeRateLimiter | undefined;
  return createRateLimitAdapter(mode, edge);
}

async function consumeStrictD1(key: string, limit: number, windowMs: number) {
  const db = await getDatabase();
  const now = Date.now();
  const resetAt = now + windowMs;
  const inserted = await db.prepare("INSERT OR IGNORE INTO rate_limit_buckets (key, count, reset_at) VALUES (?, 1, ?)")
    .bind(key, resetAt).run();
  if (Number(inserted.meta.changes ?? 0) === 1) return true;
  const consumed = await db.prepare(`UPDATE rate_limit_buckets
    SET count = CASE WHEN reset_at <= ? THEN 1 ELSE count + 1 END,
        reset_at = CASE WHEN reset_at <= ? THEN ? ELSE reset_at END
    WHERE key = ? AND (reset_at <= ? OR count < ?)`)
    .bind(now, now, resetAt, key, now, limit).run();
  return Number(consumed.meta.changes ?? 0) === 1;
}

function validPolicy(scope: string, fingerprint: string, limit: number, windowMs: number) {
  return /^[a-z0-9-]{1,80}$/.test(scope)
    && SHA256_BASE64_PATTERN.test(fingerprint)
    && Number.isInteger(limit) && limit >= 1 && limit <= 10_000
    && Number.isInteger(windowMs) && windowMs >= 1_000 && windowMs <= 7 * 24 * 60 * 60 * 1000;
}

export async function consumeRateLimit(scope: string, fingerprint: string, limit: number, windowMs: number) {
  if (!validPolicy(scope, fingerprint, limit, windowMs)) return false;
  const key = `${scope}:${fingerprint}`;
  try {
    const adapter = await getRateLimitAdapter();
    if (!await adapter.consumeEdge(key)) return false;
    return await consumeStrictD1(key, limit, windowMs);
  } catch {
    return false;
  }
}

export async function getRateLimitInfo() {
  const configuredMode = await rateLimitMode();
  try {
    const adapter = await getRateLimitAdapter();
    return { mode: adapter.mode, available: true, edgeEnabled: adapter.edgeEnabled } as const;
  } catch {
    return { mode: configuredMode, available: false, edgeEnabled: configuredMode === "cloudflare_hybrid" } as const;
  }
}
