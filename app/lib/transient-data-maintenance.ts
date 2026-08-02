import { getDatabase } from "./database";
import { getOutboxRetentionSummary, purgeExpiredOutbox } from "./notification-outbox";

export const TRANSIENT_DATA_MAINTENANCE_POLICY_VERSION = 1;

export const TRANSIENT_DATA_CATEGORIES = [
  "sessions",
  "accountTokens",
  "reauthenticationRequests",
  "reauthenticationTokens",
  "previewTokens",
  "rateLimitBuckets",
  "notificationOutbox",
] as const;

export type TransientDataCategory = (typeof TRANSIENT_DATA_CATEGORIES)[number];
export type TransientDataCounts = Record<TransientDataCategory, number>;

function emptyCounts(): TransientDataCounts {
  return {
    sessions: 0,
    accountTokens: 0,
    reauthenticationRequests: 0,
    reauthenticationTokens: 0,
    previewTokens: 0,
    rateLimitBuckets: 0,
    notificationOutbox: 0,
  };
}

function firstCount(result: D1Result<unknown>) {
  const row = result.results?.[0] as { count?: number } | undefined;
  return Number(row?.count ?? 0);
}

export async function getTransientDataMaintenanceSummary(now = Date.now(), database?: D1Database) {
  const db = database ?? await getDatabase();
  const results = await db.batch([
    db.prepare("SELECT COUNT(*) AS count FROM sessions WHERE expires_at <= ? OR idle_expires_at <= ?").bind(now, now),
    db.prepare("SELECT COUNT(*) AS count FROM account_tokens WHERE expires_at <= ?").bind(now),
    db.prepare("SELECT COUNT(*) AS count FROM account_reauthentication_requests WHERE expires_at <= ?").bind(now),
    db.prepare("SELECT COUNT(*) AS count FROM account_reauthentication_tokens WHERE expires_at <= ?").bind(now),
    db.prepare("SELECT COUNT(*) AS count FROM preview_tokens WHERE expires_at <= ?").bind(now),
    db.prepare("SELECT COUNT(*) AS count FROM rate_limit_buckets WHERE reset_at <= ?").bind(now),
  ]);
  const counts = emptyCounts();
  counts.sessions = firstCount(results[0]);
  counts.accountTokens = firstCount(results[1]);
  counts.reauthenticationRequests = firstCount(results[2]);
  counts.reauthenticationTokens = firstCount(results[3]);
  counts.previewTokens = firstCount(results[4]);
  counts.rateLimitBuckets = firstCount(results[5]);
  counts.notificationOutbox = (await getOutboxRetentionSummary(now, db)).purgeable;

  return {
    policyVersion: TRANSIENT_DATA_MAINTENANCE_POLICY_VERSION,
    counts,
    total: Object.values(counts).reduce((total, count) => total + count, 0),
  };
}

export async function purgeExpiredTransientData(now = Date.now(), database?: D1Database) {
  const db = database ?? await getDatabase();
  const results = await db.batch([
    db.prepare("DELETE FROM sessions WHERE expires_at <= ? OR idle_expires_at <= ?").bind(now, now),
    db.prepare("DELETE FROM account_tokens WHERE expires_at <= ?").bind(now),
    db.prepare("DELETE FROM account_reauthentication_requests WHERE expires_at <= ?").bind(now),
    db.prepare("DELETE FROM account_reauthentication_tokens WHERE expires_at <= ?").bind(now),
    db.prepare("DELETE FROM preview_tokens WHERE expires_at <= ?").bind(now),
    db.prepare("DELETE FROM rate_limit_buckets WHERE reset_at <= ?").bind(now),
  ]);
  const counts = emptyCounts();
  counts.sessions = Number(results[0].meta.changes ?? 0);
  counts.accountTokens = Number(results[1].meta.changes ?? 0);
  counts.reauthenticationRequests = Number(results[2].meta.changes ?? 0);
  counts.reauthenticationTokens = Number(results[3].meta.changes ?? 0);
  counts.previewTokens = Number(results[4].meta.changes ?? 0);
  counts.rateLimitBuckets = Number(results[5].meta.changes ?? 0);
  counts.notificationOutbox = await purgeExpiredOutbox(now, db);

  return {
    policyVersion: TRANSIENT_DATA_MAINTENANCE_POLICY_VERSION,
    counts,
    total: Object.values(counts).reduce((total, count) => total + count, 0),
  };
}
