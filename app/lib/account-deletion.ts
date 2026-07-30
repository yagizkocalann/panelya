import { type AccountActor, AccountRuntimeError } from "./account-runtime";
import { consumeReauthenticationToken } from "./account-reauthentication";
import { hashOpaqueToken } from "./auth";
import { auth0GatewayConfig } from "./auth0-runtime";
import { auth0ManagementConfig, deleteAuth0User } from "./auth0-management";
import { getDatabase, writeAudit } from "./database";

export function accountDeletionSummary() {
  return {
    schemaVersion: "1.0" as const,
    deleted: [
      "auth_identity",
      "profile",
      "active_sessions",
      "library",
      "reading_progress",
      "block_relationships",
    ] as const,
    anonymized: ["community_contributions"] as const,
    retained: ["legal_and_audit_records"] as const,
  };
}

type DeletionRequestRow = {
  id: string;
  status: "pending" | "completed" | "failed";
};

function deletionOperation(row: DeletionRequestRow) {
  return {
    schemaVersion: "1.0" as const,
    requestId: row.id,
    status: row.status === "completed" ? "completed" as const : "pending" as const,
  };
}

export async function deleteAccount(
  actor: AccountActor,
  confirmation: unknown,
  reauthenticationToken: unknown,
  idempotencyKey: string,
) {
  if (confirmation !== "delete_my_account" || typeof reauthenticationToken !== "string") {
    throw new AccountRuntimeError("invalid_request", "Hesap silme onayı geçersiz.", 400);
  }
  const gateway = await auth0GatewayConfig();
  const management = gateway ? await auth0ManagementConfig(gateway) : null;
  if (!gateway || !management) {
    throw new AccountRuntimeError("service_unavailable", "Kimlik yönetim sağlayıcısı yapılandırılmamış.", 503, false, 300);
  }
  const db = await getDatabase();
  const idempotencyKeyHash = await hashOpaqueToken(`${actor.user.id}\n${idempotencyKey}`);
  const existing = await db.prepare(`SELECT id, status FROM account_deletion_requests
    WHERE user_id = ? AND idempotency_key_hash = ?`)
    .bind(actor.user.id, idempotencyKeyHash)
    .first<DeletionRequestRow>();
  if (existing && existing.status !== "failed") return deletionOperation(existing);

  const provider = await consumeReauthenticationToken(actor, "account_deletion", reauthenticationToken);
  if (provider.issuer !== gateway.issuer) {
    throw new AccountRuntimeError("reauthentication_invalid", "Yeniden doğrulama kanıtı geçersiz.", 401, true);
  }
  const requestId = existing?.id ?? crypto.randomUUID();
  const now = Date.now();
  let deletionStart;
  try {
    deletionStart = await db.batch([
      existing
        ? db.prepare(`UPDATE account_deletion_requests
            SET status = 'pending', attempts = attempts + 1, last_error = NULL, updated_at = ?
            WHERE id = ? AND user_id = ? AND status = 'failed'`)
          .bind(now, requestId, actor.user.id)
        : db.prepare(`INSERT INTO account_deletion_requests
            (id, user_id, idempotency_key_hash, status, attempts, last_error, created_at, updated_at, completed_at)
            VALUES (?, ?, ?, 'pending', 1, NULL, ?, ?, NULL)`)
          .bind(requestId, actor.user.id, idempotencyKeyHash, now, now),
      db.prepare(`UPDATE users SET status = 'deletion_pending', sessions_valid_after = ?, updated_at = ?
        WHERE id = ? AND status = 'active'`).bind(now, now, actor.user.id),
      db.prepare("DELETE FROM sessions WHERE user_id = ?").bind(actor.user.id),
    ]);
  } catch {
    const concurrent = await db.prepare(`SELECT id, status FROM account_deletion_requests
      WHERE user_id = ? AND idempotency_key_hash = ?`)
      .bind(actor.user.id, idempotencyKeyHash)
      .first<DeletionRequestRow>();
    if (concurrent && concurrent.status !== "failed") return deletionOperation(concurrent);
    throw new AccountRuntimeError("service_unavailable", "Hesap silme isteği başlatılamadı.", 503, false, 60);
  }
  if (Number(deletionStart[1]?.meta.changes ?? 0) !== 1) {
    await db.prepare(`UPDATE account_deletion_requests
      SET status = 'failed', last_error = 'account_not_active', updated_at = ?
      WHERE id = ?`).bind(Date.now(), requestId).run();
    throw new AccountRuntimeError("conflict", "Hesap silme işlemi zaten başlatılmış.", 409);
  }
  try {
    await deleteAuth0User(management, provider.subject);
  } catch (error) {
    const failedAt = Date.now();
    await db.batch([
      db.prepare(`UPDATE account_deletion_requests
        SET status = 'failed', last_error = 'provider_delete_failed', updated_at = ?
        WHERE id = ?`).bind(failedAt, requestId),
      db.prepare(`UPDATE users SET status = 'active', updated_at = ?
        WHERE id = ? AND status = 'deletion_pending'`).bind(failedAt, actor.user.id),
    ]);
    throw error;
  }

  const completedAt = Date.now();
  const deletedEmail = `deleted-${crypto.randomUUID()}@deleted.invalid`;
  try {
    await db.batch([
      db.prepare("DELETE FROM library_items WHERE user_id = ?").bind(actor.user.id),
      db.prepare("DELETE FROM reading_progress WHERE user_id = ?").bind(actor.user.id),
      db.prepare("DELETE FROM series_subscriptions WHERE user_id = ?").bind(actor.user.id),
      db.prepare("DELETE FROM user_blocks WHERE blocker_user_id = ? OR blocked_user_id = ?")
        .bind(actor.user.id, actor.user.id),
      db.prepare("DELETE FROM review_likes WHERE user_id = ?").bind(actor.user.id),
      db.prepare("DELETE FROM review_reports WHERE reporter_user_id = ?").bind(actor.user.id),
      db.prepare("DELETE FROM account_tokens WHERE user_id = ?").bind(actor.user.id),
      db.prepare("DELETE FROM notification_outbox WHERE user_id = ?").bind(actor.user.id),
      db.prepare("DELETE FROM provider_identities WHERE user_id = ?").bind(actor.user.id),
      db.prepare("DELETE FROM account_reauthentication_requests WHERE user_id = ?").bind(actor.user.id),
      db.prepare("DELETE FROM account_reauthentication_tokens WHERE user_id = ?").bind(actor.user.id),
      db.prepare("UPDATE audit_events SET user_id = NULL WHERE user_id = ?").bind(actor.user.id),
      db.prepare(`UPDATE users
        SET email = ?, display_name = 'Silinmiş hesap', password_hash = 'deleted$disabled',
            role = 'reader', status = 'deleted', email_verified_at = NULL, updated_at = ?
        WHERE id = ?`).bind(deletedEmail, completedAt, actor.user.id),
      db.prepare(`UPDATE account_deletion_requests
        SET status = 'completed', last_error = NULL, updated_at = ?, completed_at = ?
        WHERE id = ?`).bind(completedAt, completedAt, requestId),
    ]);
    await writeAudit(null, "account.deletion_completed", { requestId });
  } catch {
    await db.prepare(`UPDATE account_deletion_requests
      SET status = 'failed', last_error = 'local_cleanup_failed', updated_at = ?
      WHERE id = ?`).bind(Date.now(), requestId).run();
    throw new AccountRuntimeError("service_unavailable", "Hesap temizliği yeniden denenecek.", 503, false, 300);
  }
  return deletionOperation({ id: requestId, status: "completed" });
}
