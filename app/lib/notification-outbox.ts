import { getDatabase } from "./database";

const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;

export const OUTBOX_RETENTION_POLICY_VERSION = 1;
export const OUTBOX_RETENTION = {
  opened: 1 * DAY_MS,
  queuedPasswordReset: 1 * DAY_MS,
  queuedVerification: 2 * DAY_MS,
  queuedAdminInvitation: 2 * DAY_MS,
  queuedSecurityNotice: 30 * DAY_MS,
} as const;

type RetentionCutoffs = ReturnType<typeof retentionCutoffs>;

function retentionCutoffs(now: number) {
  return {
    opened: now - OUTBOX_RETENTION.opened,
    passwordReset: now - OUTBOX_RETENTION.queuedPasswordReset,
    verification: now - OUTBOX_RETENTION.queuedVerification,
    adminInvitation: now - OUTBOX_RETENTION.queuedAdminInvitation,
    securityNotice: now - OUTBOX_RETENTION.queuedSecurityNotice,
  };
}

const RETENTION_WHERE = `(
  (status = 'opened' AND COALESCE(opened_at, created_at) <= ?)
  OR (status = 'queued' AND kind = 'password_reset' AND created_at <= ?)
  OR (status = 'queued' AND kind = 'verify_email' AND created_at <= ?)
  OR (status = 'queued' AND kind = 'security_notice' AND action_url LIKE '%/accept-admin-invite?%' AND created_at <= ?)
  OR (status = 'queued' AND kind = 'security_notice' AND (action_url IS NULL OR action_url NOT LIKE '%/accept-admin-invite?%') AND created_at <= ?)
)`;

function bindCutoffs<T extends { bind(...values: Array<string | number | null>): T }>(statement: T, cutoffs: RetentionCutoffs) {
  return statement.bind(cutoffs.opened, cutoffs.passwordReset, cutoffs.verification, cutoffs.adminInvitation, cutoffs.securityNotice);
}

export type OutboxRetentionSummary = {
  total: number;
  purgeable: number;
  queuedWithAction: number;
  oldestCreatedAt: number | null;
  policyVersion: number;
};

export async function getOutboxRetentionSummary(now = Date.now()): Promise<OutboxRetentionSummary> {
  const db = await getDatabase();
  const cutoffs = retentionCutoffs(now);
  const [inventory, purgeable] = await db.batch([
    db.prepare(`SELECT COUNT(*) AS total,
      SUM(CASE WHEN status = 'queued' AND action_url IS NOT NULL THEN 1 ELSE 0 END) AS queued_with_action,
      MIN(created_at) AS oldest_created_at FROM notification_outbox`),
    bindCutoffs(db.prepare(`SELECT COUNT(*) AS count FROM notification_outbox WHERE ${RETENTION_WHERE}`), cutoffs),
  ]);
  const inventoryRow = inventory.results?.[0] as { total?: number; queued_with_action?: number | null; oldest_created_at?: number | null } | undefined;
  const purgeableRow = purgeable.results?.[0] as { count?: number } | undefined;
  return {
    total: Number(inventoryRow?.total ?? 0),
    purgeable: Number(purgeableRow?.count ?? 0),
    queuedWithAction: Number(inventoryRow?.queued_with_action ?? 0),
    oldestCreatedAt: inventoryRow?.oldest_created_at === null || inventoryRow?.oldest_created_at === undefined ? null : Number(inventoryRow.oldest_created_at),
    policyVersion: OUTBOX_RETENTION_POLICY_VERSION,
  };
}

export async function purgeExpiredOutbox(now = Date.now()) {
  const db = await getDatabase();
  const result = await bindCutoffs(db.prepare(`DELETE FROM notification_outbox WHERE ${RETENTION_WHERE}`), retentionCutoffs(now)).run();
  return Number(result.meta.changes ?? 0);
}
