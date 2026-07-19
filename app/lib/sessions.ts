import { getCurrentSessionHash, getCurrentUser } from "./auth";
import { getDatabase } from "./database";

export type AccountSession = {
  tokenHash: string;
  scope: "public" | "studio";
  createdAt: number;
  expiresAt: number;
  idleExpiresAt: number;
  lastSeenAt: number;
  userAgent: string | null;
  isCurrent: boolean;
};

export async function listCurrentUserSessions(): Promise<AccountSession[]> {
  const user = await getCurrentUser();
  if (!user) return [];
  const db = await getDatabase();
  const currentHash = await getCurrentSessionHash();
  const now = Date.now();
  await db.prepare("DELETE FROM sessions WHERE expires_at <= ? OR idle_expires_at <= ?").bind(now, now).run();
  const rows = await db.prepare(`SELECT token_hash, scope, created_at, expires_at, idle_expires_at, last_seen_at, user_agent FROM sessions
    WHERE user_id = ? ORDER BY last_seen_at DESC`).bind(user.id).all<{
      token_hash: string;
      scope: "public" | "studio";
      created_at: number;
      expires_at: number;
      idle_expires_at: number;
      last_seen_at: number;
      user_agent: string | null;
    }>();
  return rows.results.map((row) => ({
    tokenHash: row.token_hash,
    scope: row.scope,
    createdAt: row.created_at,
    expiresAt: row.expires_at,
    idleExpiresAt: row.idle_expires_at,
    lastSeenAt: row.last_seen_at,
    userAgent: row.user_agent,
    isCurrent: row.token_hash === currentHash,
  }));
}
