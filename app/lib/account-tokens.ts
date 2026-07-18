import { createOpaqueToken, hashOpaqueToken } from "./auth";
import { getDatabase } from "./database";

export type AccountTokenPurpose = "verify_email" | "password_reset";

export type AccountTokenRow = {
  id: string;
  user_id: string;
  purpose: AccountTokenPurpose;
  target_email: string;
  expires_at: number;
  used_at: number | null;
};

const TOKEN_TTL: Record<AccountTokenPurpose, number> = {
  verify_email: 24 * 60 * 60 * 1000,
  password_reset: 30 * 60 * 1000,
};

export async function issueAccountToken(userId: string, purpose: AccountTokenPurpose, targetEmail: string) {
  const db = await getDatabase();
  const rawToken = createOpaqueToken();
  const tokenHash = await hashOpaqueToken(rawToken);
  const now = Date.now();
  await db.batch([
    db.prepare("UPDATE account_tokens SET used_at = ? WHERE user_id = ? AND purpose = ? AND used_at IS NULL").bind(now, userId, purpose),
    db.prepare(`INSERT INTO account_tokens (id, token_hash, user_id, purpose, target_email, expires_at, used_at, created_at)
      VALUES (?, ?, ?, ?, ?, ?, NULL, ?)`).bind(crypto.randomUUID(), tokenHash, userId, purpose, targetEmail, now + TOKEN_TTL[purpose], now),
  ]);
  return rawToken;
}

export async function inspectAccountToken(rawToken: string, purpose: AccountTokenPurpose) {
  if (!rawToken || rawToken.length > 200) return null;
  const db = await getDatabase();
  return db.prepare(`SELECT id, user_id, purpose, target_email, expires_at, used_at FROM account_tokens
    WHERE token_hash = ? AND purpose = ? AND used_at IS NULL AND expires_at > ?`)
    .bind(await hashOpaqueToken(rawToken), purpose, Date.now()).first<AccountTokenRow>();
}

export async function consumeAccountToken(rawToken: string, purpose: AccountTokenPurpose) {
  const db = await getDatabase();
  const result = await db.prepare(`UPDATE account_tokens SET used_at = ?
    WHERE token_hash = ? AND purpose = ? AND used_at IS NULL AND expires_at > ?
    RETURNING id, user_id, purpose, target_email, expires_at, used_at`)
    .bind(Date.now(), await hashOpaqueToken(rawToken), purpose, Date.now()).first<AccountTokenRow>();
  return result ?? null;
}
