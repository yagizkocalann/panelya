import { getCurrentSessionHash, getCurrentUser } from "./auth";
import { getDatabase } from "./database";

export type AccountSession = {
  tokenHash: string;
  createdAt: number;
  expiresAt: number;
  userAgent: string | null;
  isCurrent: boolean;
};

export async function listCurrentUserSessions(): Promise<AccountSession[]> {
  const user = await getCurrentUser();
  if (!user) return [];
  const db = await getDatabase();
  const currentHash = await getCurrentSessionHash();
  await db.prepare("DELETE FROM sessions WHERE expires_at <= ?").bind(Date.now()).run();
  const rows = await db.prepare(`SELECT token_hash, created_at, expires_at, user_agent FROM sessions
    WHERE user_id = ? ORDER BY created_at DESC`).bind(user.id).all<{ token_hash: string; created_at: number; expires_at: number; user_agent: string | null }>();
  return rows.results.map((row) => ({ tokenHash: row.token_hash, createdAt: row.created_at, expiresAt: row.expires_at, userAgent: row.user_agent, isCurrent: row.token_hash === currentHash }));
}
