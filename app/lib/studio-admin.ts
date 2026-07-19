import { getDatabase } from "./database";

export type StudioUser = {
  id: string;
  email: string;
  displayName: string;
  role: "reader" | "admin";
  emailVerifiedAt: number | null;
  createdAt: number;
  sessionCount: number;
  libraryCount: number;
  reviewCount: number;
};

type StudioUserRow = {
  id: string;
  email: string;
  display_name: string;
  role: "reader" | "admin";
  email_verified_at: number | null;
  created_at: number;
  session_count: number;
  library_count: number;
  review_count: number;
};

export async function listStudioUsers() {
  const db = await getDatabase();
  const rows = await db.prepare(`SELECT u.id, u.email, u.display_name, u.role, u.email_verified_at, u.created_at,
    (SELECT COUNT(*) FROM sessions s WHERE s.user_id = u.id AND s.expires_at > ?) AS session_count,
    (SELECT COUNT(*) FROM library_items l WHERE l.user_id = u.id) AS library_count,
    (SELECT COUNT(*) FROM reviews r WHERE r.user_id = u.id) AS review_count
    FROM users u ORDER BY CASE u.role WHEN 'admin' THEN 0 ELSE 1 END, u.created_at DESC`).bind(Date.now()).all<StudioUserRow>();
  return rows.results.map((row): StudioUser => ({
    id: row.id,
    email: row.email,
    displayName: row.display_name,
    role: row.role,
    emailVerifiedAt: row.email_verified_at === null ? null : Number(row.email_verified_at),
    createdAt: Number(row.created_at),
    sessionCount: Number(row.session_count),
    libraryCount: Number(row.library_count),
    reviewCount: Number(row.review_count),
  }));
}

export type AuditEvent = {
  id: string;
  userId: string | null;
  actorName: string | null;
  actorEmail: string | null;
  action: string;
  metadata: Record<string, unknown>;
  createdAt: number;
};

type AuditRow = {
  id: string;
  user_id: string | null;
  display_name: string | null;
  email: string | null;
  action: string;
  metadata: string | null;
  created_at: number;
};

export const AUDIT_GROUPS = ["account", "admin", "contact", "content", "library", "media", "moderation", "preview", "review", "subscription"] as const;

function safeMetadata(raw: string | null) {
  if (!raw) return {};
  try {
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    const allowed = new Set([
      "seriesSlug", "episodeSlug", "publicationStatus", "mediaId", "kind", "mimeType", "byteSize", "width", "height",
      "jobs", "jobId", "panelId", "from", "to", "grantId", "expiresAt", "reviewId", "replyId", "reason", "containsSpoiler",
      "rating", "messageId", "role", "targetUserId", "previousRole", "newRole", "position", "reportId", "invitationId",
      "deletedCount", "policyVersion", "subscriberCount", "queuedCount", "failedCount",
    ]);
    return Object.fromEntries(Object.entries(parsed).filter(([key]) => allowed.has(key)));
  } catch {
    return {};
  }
}

export async function listAuditEvents(input: { group?: string; userId?: string; before?: number; limit?: number }) {
  const db = await getDatabase();
  const clauses: string[] = [];
  const values: Array<string | number> = [];
  if (AUDIT_GROUPS.includes(input.group as (typeof AUDIT_GROUPS)[number])) {
    clauses.push("a.action LIKE ?");
    values.push(`${input.group}.%`);
  }
  if (input.userId) {
    clauses.push("a.user_id = ?");
    values.push(input.userId);
  }
  if (input.before && Number.isFinite(input.before)) {
    clauses.push("a.created_at < ?");
    values.push(input.before);
  }
  const limit = Math.max(1, Math.min(input.limit ?? 60, 100));
  const where = clauses.length ? `WHERE ${clauses.join(" AND ")}` : "";
  const rows = await db.prepare(`SELECT a.id, a.user_id, u.display_name, u.email, a.action, a.metadata, a.created_at
    FROM audit_events a LEFT JOIN users u ON u.id = a.user_id ${where}
    ORDER BY a.created_at DESC LIMIT ?`).bind(...values, limit + 1).all<AuditRow>();
  const hasMore = rows.results.length > limit;
  return {
    events: rows.results.slice(0, limit).map((row): AuditEvent => ({
      id: row.id,
      userId: row.user_id,
      actorName: row.display_name,
      actorEmail: row.email,
      action: row.action,
      metadata: safeMetadata(row.metadata),
      createdAt: Number(row.created_at),
    })),
    hasMore,
  };
}
