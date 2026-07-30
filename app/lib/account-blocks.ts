import { type AccountActor, AccountRuntimeError } from "./account-runtime";
import { getDatabase, writeAudit } from "./database";

type BlockedAccountRow = {
  id: string;
  display_name: string;
};

function validUserId(userId: string) {
  return userId.length >= 1 && userId.length <= 128 && !/[\u0000-\u001f]/.test(userId);
}

export async function listBlockedAccounts(actor: AccountActor) {
  const db = await getDatabase();
  const accounts = (await db.prepare(`SELECT u.id, u.display_name
    FROM user_blocks b JOIN users u ON u.id = b.blocked_user_id
    WHERE b.blocker_user_id = ?
    ORDER BY u.display_name COLLATE NOCASE, u.id`)
    .bind(actor.user.id)
    .all<BlockedAccountRow>()).results;
  return {
    schemaVersion: "1.0" as const,
    accounts: accounts.map((account) => ({ id: account.id, displayName: account.display_name })),
  };
}

export async function blockAccount(actor: AccountActor, userId: string) {
  if (!validUserId(userId) || userId === actor.user.id) {
    throw new AccountRuntimeError("invalid_request", "Engellenecek hesap geçersiz.", 400);
  }
  const db = await getDatabase();
  const target = await db.prepare("SELECT id FROM users WHERE id = ? AND status = 'active'")
    .bind(userId).first<{ id: string }>();
  if (!target) throw new AccountRuntimeError("not_found", "Hesap bulunamadı.", 404);
  await db.prepare(`INSERT OR IGNORE INTO user_blocks
    (blocker_user_id, blocked_user_id, created_at) VALUES (?, ?, ?)`)
    .bind(actor.user.id, userId, Date.now()).run();
  await writeAudit(actor.user.id, "account.user_blocked", { targetUserId: userId });
  return { schemaVersion: "1.0" as const, accepted: true as const };
}

export async function unblockAccount(actor: AccountActor, userId: string) {
  if (!validUserId(userId)) throw new AccountRuntimeError("invalid_request", "Hesap kimliği geçersiz.", 400);
  const db = await getDatabase();
  await db.prepare("DELETE FROM user_blocks WHERE blocker_user_id = ? AND blocked_user_id = ?")
    .bind(actor.user.id, userId).run();
  await writeAudit(actor.user.id, "account.user_unblocked", { targetUserId: userId });
  return { schemaVersion: "1.0" as const, accepted: true as const };
}
