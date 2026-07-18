import { hashOpaqueToken } from "./auth";
import { getDatabase } from "./database";

export async function requestFingerprint(request: Request, value: string) {
  const client = request.headers.get("cf-connecting-ip") ?? request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "local";
  return hashOpaqueToken(`${client}:${value.trim().toLowerCase()}`);
}

export async function consumeRateLimit(scope: string, fingerprint: string, limit: number, windowMs: number) {
  const db = await getDatabase();
  const key = `${scope}:${fingerprint}`;
  const now = Date.now();
  const row = await db.prepare("SELECT count, reset_at FROM rate_limit_buckets WHERE key = ?").bind(key).first<{ count: number; reset_at: number }>();
  if (!row || row.reset_at <= now) {
    await db.prepare(`INSERT INTO rate_limit_buckets (key, count, reset_at) VALUES (?, 1, ?)
      ON CONFLICT(key) DO UPDATE SET count = 1, reset_at = excluded.reset_at`).bind(key, now + windowMs).run();
    return true;
  }
  if (row.count >= limit) return false;
  await db.prepare("UPDATE rate_limit_buckets SET count = count + 1 WHERE key = ? AND reset_at > ?").bind(key, now).run();
  return true;
}
