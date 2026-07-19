import { createOpaqueToken, hashOpaqueToken, hashPassword, normalizeEmail, type LocalUser } from "./auth";
import { getDatabase } from "./database";
import { sendNotification } from "./notifications";

const INVITATION_TTL_MS = 24 * 60 * 60 * 1000;

type InvitationRow = {
  id: string;
  email: string;
  token_hash: string;
  invited_by_user_id: string | null;
  inviter_name?: string | null;
  status: "pending" | "accepted" | "revoked";
  expires_at: number;
  accepted_at: number | null;
  revoked_at: number | null;
  created_at: number;
  updated_at: number;
};

export type StudioAdminInvitation = {
  id: string;
  email: string;
  invitedByName: string | null;
  status: "pending" | "expired" | "accepted" | "revoked";
  expiresAt: number;
  acceptedAt: number | null;
  revokedAt: number | null;
  createdAt: number;
  updatedAt: number;
};

export type AdminInvitationErrorCode = "invalid_email" | "account_exists" | "pending_exists" | "not_pending";

export class AdminInvitationError extends Error {
  constructor(public readonly code: AdminInvitationErrorCode) {
    super(code);
  }
}

export function validateInvitationEmail(email: string) {
  const normalized = normalizeEmail(email);
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized) && normalized.length <= 160 ? normalized : null;
}

function invitationUrl(origin: string, rawToken: string) {
  const url = new URL("/accept-admin-invite", origin);
  url.searchParams.set("token", rawToken);
  return url.toString();
}

async function deliverInvitation(email: string, origin: string, rawToken: string) {
  await sendNotification({
    userId: null,
    recipient: email,
    kind: "security_notice",
    subject: "Panelya Studio yönetici daveti",
    body: "Panelya Studio yönetici hesabını 24 saat içinde oluştur. Bu bağlantı tek kullanımlıktır.",
    actionUrl: invitationUrl(origin, rawToken),
  });
}

export async function listAdminInvitations(limit = 50) {
  const db = await getDatabase();
  const rows = await db.prepare(`SELECT i.id, i.email, i.invited_by_user_id, u.display_name AS inviter_name,
      i.status, i.expires_at, i.accepted_at, i.revoked_at, i.created_at, i.updated_at
    FROM admin_invitations i LEFT JOIN users u ON u.id = i.invited_by_user_id
    ORDER BY CASE i.status WHEN 'pending' THEN 0 ELSE 1 END, i.updated_at DESC LIMIT ?`)
    .bind(Math.max(1, Math.min(limit, 100))).all<InvitationRow>();
  const now = Date.now();
  return rows.results.map((row): StudioAdminInvitation => ({
    id: row.id,
    email: row.email,
    invitedByName: row.inviter_name ?? null,
    status: row.status === "pending" && Number(row.expires_at) <= now ? "expired" : row.status,
    expiresAt: Number(row.expires_at),
    acceptedAt: row.accepted_at === null ? null : Number(row.accepted_at),
    revokedAt: row.revoked_at === null ? null : Number(row.revoked_at),
    createdAt: Number(row.created_at),
    updatedAt: Number(row.updated_at),
  }));
}

export async function createAdminInvitation(invitedByUserId: string, email: string, origin: string) {
  const normalized = validateInvitationEmail(email);
  if (!normalized) throw new AdminInvitationError("invalid_email");
  const db = await getDatabase();
  const account = await db.prepare("SELECT id FROM users WHERE email = ?").bind(normalized).first<{ id: string }>();
  if (account) throw new AdminInvitationError("account_exists");
  const pending = await db.prepare("SELECT id FROM admin_invitations WHERE email = ? AND status = 'pending'")
    .bind(normalized).first<{ id: string }>();
  if (pending) throw new AdminInvitationError("pending_exists");
  const rawToken = createOpaqueToken();
  const now = Date.now();
  const invitation = { id: crypto.randomUUID(), email: normalized, expiresAt: now + INVITATION_TTL_MS };
  await db.prepare(`INSERT INTO admin_invitations
    (id, email, token_hash, invited_by_user_id, status, expires_at, accepted_at, revoked_at, created_at, updated_at)
    VALUES (?, ?, ?, ?, 'pending', ?, NULL, NULL, ?, ?)`)
    .bind(invitation.id, invitation.email, await hashOpaqueToken(rawToken), invitedByUserId, invitation.expiresAt, now, now).run();
  await deliverInvitation(invitation.email, origin, rawToken);
  return invitation;
}

export async function resendAdminInvitation(id: string, origin: string) {
  const db = await getDatabase();
  const row = await db.prepare("SELECT id, email, status FROM admin_invitations WHERE id = ?")
    .bind(id).first<Pick<InvitationRow, "id" | "email" | "status">>();
  if (!row || row.status !== "pending") throw new AdminInvitationError("not_pending");
  const account = await db.prepare("SELECT id FROM users WHERE email = ?").bind(row.email).first<{ id: string }>();
  if (account) throw new AdminInvitationError("account_exists");
  const rawToken = createOpaqueToken();
  const now = Date.now();
  const expiresAt = now + INVITATION_TTL_MS;
  const result = await db.prepare(`UPDATE admin_invitations SET token_hash = ?, expires_at = ?, updated_at = ?
    WHERE id = ? AND status = 'pending'`)
    .bind(await hashOpaqueToken(rawToken), expiresAt, now, id).run();
  if (Number(result.meta.changes ?? 0) !== 1) throw new AdminInvitationError("not_pending");
  await deliverInvitation(row.email, origin, rawToken);
  return { id, email: row.email, expiresAt };
}

export async function revokeAdminInvitation(id: string) {
  const db = await getDatabase();
  const now = Date.now();
  const result = await db.prepare(`UPDATE admin_invitations SET status = 'revoked', revoked_at = ?, updated_at = ?
    WHERE id = ? AND status = 'pending'`).bind(now, now, id).run();
  return Number(result.meta.changes ?? 0) === 1;
}

export async function inspectAdminInvitation(rawToken: string) {
  if (!rawToken) return null;
  const db = await getDatabase();
  return db.prepare(`SELECT id, email, expires_at FROM admin_invitations
    WHERE token_hash = ? AND status = 'pending' AND expires_at > ?`)
    .bind(await hashOpaqueToken(rawToken), Date.now()).first<{ id: string; email: string; expires_at: number }>();
}

export async function acceptAdminInvitation(rawToken: string, displayName: string, password: string) {
  const invitation = await inspectAdminInvitation(rawToken);
  if (!invitation) return null;
  const db = await getDatabase();
  const now = Date.now();
  const id = crypto.randomUUID();
  const passwordHash = await hashPassword(password);
  const tokenHash = await hashOpaqueToken(rawToken);
  const results = await db.batch([
    db.prepare(`INSERT INTO users (id, email, display_name, password_hash, role, email_verified_at, created_at, updated_at)
      SELECT ?, email, ?, ?, 'admin', ?, ?, ? FROM admin_invitations
      WHERE id = ? AND token_hash = ? AND status = 'pending' AND expires_at > ?`)
      .bind(id, displayName.trim(), passwordHash, now, now, now, invitation.id, tokenHash, now),
    db.prepare(`UPDATE admin_invitations SET status = 'accepted', accepted_at = ?, updated_at = ?
      WHERE id = ? AND token_hash = ? AND status = 'pending' AND expires_at > ?`)
      .bind(now, now, invitation.id, tokenHash, now),
  ]);
  if (Number(results[0]?.meta.changes ?? 0) !== 1 || Number(results[1]?.meta.changes ?? 0) !== 1) return null;
  return {
    invitationId: invitation.id,
    user: { id, email: invitation.email, displayName: displayName.trim(), role: "admin", emailVerifiedAt: now, createdAt: now } satisfies LocalUser,
  };
}

export async function hasAdminAccount() {
  const db = await getDatabase();
  const row = await db.prepare("SELECT 1 AS found FROM users WHERE role = 'admin' LIMIT 1").first<{ found: number }>();
  return Boolean(row);
}

export async function createBootstrapAdmin(displayName: string, email: string, password: string) {
  const normalized = validateInvitationEmail(email);
  if (!normalized) throw new AdminInvitationError("invalid_email");
  const db = await getDatabase();
  const now = Date.now();
  const id = crypto.randomUUID();
  const result = await db.prepare(`INSERT INTO users
    (id, email, display_name, password_hash, role, email_verified_at, created_at, updated_at)
    SELECT ?, ?, ?, ?, 'admin', ?, ?, ? WHERE NOT EXISTS (SELECT 1 FROM users WHERE role = 'admin')`)
    .bind(id, normalized, displayName.trim(), await hashPassword(password), now, now, now).run();
  if (Number(result.meta.changes ?? 0) !== 1) return null;
  return { id, email: normalized, displayName: displayName.trim(), role: "admin", emailVerifiedAt: now, createdAt: now } satisfies LocalUser;
}
