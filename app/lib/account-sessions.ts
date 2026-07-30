import {
  accountRuntimeSecret,
  type AccountActor,
  AccountRuntimeError,
  publicSessionId,
} from "./account-runtime";
import { auth0GatewayConfig } from "./auth0-runtime";
import {
  auth0ManagementConfig,
  deleteAuth0DeviceCredential,
  findAuth0SubjectByEmail,
  listAuth0DeviceCredentials,
} from "./auth0-management";
import { getDatabase, writeAudit } from "./database";

type WebSessionRow = {
  token_hash: string;
  last_seen_at: number;
  created_at: number;
  user_agent: string | null;
};

function webDeviceLabel(userAgent: string | null) {
  if (!userAgent) return "Web tarayıcısı";
  if (/edg\//i.test(userAgent)) return "Microsoft Edge";
  if (/firefox\//i.test(userAgent)) return "Firefox";
  if (/chrome\//i.test(userAgent)) return "Google Chrome";
  if (/safari\//i.test(userAgent)) return "Safari";
  return "Web tarayıcısı";
}

function nativePlatform(deviceName: string | undefined): "android" | "ios" | "unspecified" {
  if (/android|pixel|galaxy/i.test(deviceName ?? "")) return "android";
  if (/iphone|ipad|ios/i.test(deviceName ?? "")) return "ios";
  return "unspecified";
}

async function webSessionRows(actor: AccountActor) {
  const db = await getDatabase();
  return (await db.prepare(`SELECT token_hash, last_seen_at, created_at, user_agent
    FROM sessions
    WHERE user_id = ? AND scope = 'public' AND expires_at > ? AND idle_expires_at > ?
    ORDER BY last_seen_at DESC`).bind(actor.user.id, Date.now(), Date.now()).all<WebSessionRow>()).results;
}

async function providerSubject(actor: AccountActor) {
  if (actor.providerSubject) return actor.providerSubject;
  if (!actor.issuer || !actor.providerSubjectHash) return null;
  const gateway = await auth0GatewayConfig();
  if (!gateway || gateway.issuer !== actor.issuer) return null;
  const management = await auth0ManagementConfig(gateway);
  if (!management) return null;
  return findAuth0SubjectByEmail(
    management,
    actor.user.email,
    actor.issuer,
    actor.providerSubjectHash,
  );
}

async function nativeSessionContext(actor: AccountActor) {
  const gateway = await auth0GatewayConfig();
  if (!gateway || !actor.issuer || gateway.issuer !== actor.issuer) return null;
  const management = await auth0ManagementConfig(gateway);
  if (!management) return null;
  const subject = await providerSubject(actor);
  if (!subject) return null;
  return { management, subject, credentials: await listAuth0DeviceCredentials(management, subject) };
}

export async function listAccountSessions(actor: AccountActor) {
  const secret = await accountRuntimeSecret();
  const web = await webSessionRows(actor);
  const sessions = await Promise.all(web.map(async (session) => ({
    id: await publicSessionId("web", session.token_hash, secret),
    deviceLabel: webDeviceLabel(session.user_agent),
    platform: "web" as const,
    lastActiveAt: new Date(session.last_seen_at || session.created_at).toISOString(),
    current: session.token_hash === actor.currentSessionHash,
    revocable: true,
  })));
  const native = await nativeSessionContext(actor);
  if (actor.issuer && !native) {
    throw new AccountRuntimeError("service_unavailable", "Mobil oturum envanteri kullanılamıyor.", 503, false, 300);
  }
  if (native) {
    sessions.push(...await Promise.all(native.credentials.map(async (credential) => ({
      id: await publicSessionId("native", credential.id, secret),
      deviceLabel: credential.device_name?.trim().slice(0, 120) || "Mobil cihaz",
      platform: nativePlatform(credential.device_name),
      lastActiveAt: new Date(credential.last_used_at ?? credential.created_at ?? Date.now()).toISOString(),
      // Auth0 access tokens do not expose the originating device credential id.
      current: false,
      revocable: true,
    }))));
  }
  sessions.sort((left, right) => right.lastActiveAt.localeCompare(left.lastActiveAt));
  return { schemaVersion: "1.0" as const, sessions };
}

export async function revokeAccountSession(actor: AccountActor, sessionId: string) {
  if (!/^[wn]_[A-Za-z0-9_-]{20,100}$/.test(sessionId)) {
    throw new AccountRuntimeError("not_found", "Oturum bulunamadı.", 404);
  }
  const secret = await accountRuntimeSecret();
  if (sessionId.startsWith("w_")) {
    const db = await getDatabase();
    const sessions = await webSessionRows(actor);
    const target = (await Promise.all(sessions.map(async (row) => ({
      row,
      id: await publicSessionId("web", row.token_hash, secret),
    })))).find((candidate) => candidate.id === sessionId);
    if (!target) throw new AccountRuntimeError("not_found", "Oturum bulunamadı.", 404);
    await db.prepare("DELETE FROM sessions WHERE token_hash = ? AND user_id = ?")
      .bind(target.row.token_hash, actor.user.id).run();
    await writeAudit(actor.user.id, "account.session_revoked", { platform: "web", current: target.row.token_hash === actor.currentSessionHash });
    return {
      schemaVersion: "1.0" as const,
      revokedCount: 1,
      currentSessionRevoked: target.row.token_hash === actor.currentSessionHash,
    };
  }
  const native = await nativeSessionContext(actor);
  if (!native) throw new AccountRuntimeError("service_unavailable", "Mobil oturum envanteri kullanılamıyor.", 503, false, 300);
  const target = (await Promise.all(native.credentials.map(async (credential) => ({
    credential,
    id: await publicSessionId("native", credential.id, secret),
  })))).find((candidate) => candidate.id === sessionId);
  if (!target) throw new AccountRuntimeError("not_found", "Oturum bulunamadı.", 404);
  await deleteAuth0DeviceCredential(native.management, target.credential.id);
  await writeAudit(actor.user.id, "account.session_revoked", { platform: "native" });
  return { schemaVersion: "1.0" as const, revokedCount: 1, currentSessionRevoked: false };
}

export async function revokeAccountSessions(actor: AccountActor, scope: "others" | "all") {
  if (scope === "others" && actor.transport === "mobile") {
    throw new AccountRuntimeError(
      "service_unavailable",
      "Mevcut mobil oturum kesin olarak eşlenmeden diğer mobil oturumlar kapatılamaz.",
      503,
      false,
      300,
    );
  }
  const native = await nativeSessionContext(actor);
  if (actor.issuer && !native) {
    throw new AccountRuntimeError("service_unavailable", "Mobil oturum envanteri kullanılamıyor.", 503, false, 300);
  }
  const db = await getDatabase();
  const web = await webSessionRows(actor);
  const webTargets = scope === "all"
    ? web
    : web.filter((session) => session.token_hash !== actor.currentSessionHash);
  if (webTargets.length > 0) {
    const placeholders = webTargets.map(() => "?").join(",");
    await db.prepare(`DELETE FROM sessions WHERE user_id = ? AND token_hash IN (${placeholders})`)
      .bind(actor.user.id, ...webTargets.map((session) => session.token_hash)).run();
  }
  let revokedCount = webTargets.length;
  if (native && (scope === "all" || actor.transport === "web")) {
    await Promise.all(native.credentials.map((credential) => deleteAuth0DeviceCredential(native.management, credential.id)));
    revokedCount += native.credentials.length;
  }
  if (scope === "all") {
    await db.prepare("UPDATE users SET sessions_valid_after = ?, updated_at = ? WHERE id = ?")
      .bind(Date.now(), Date.now(), actor.user.id).run();
  }
  const currentSessionRevoked = scope === "all" && (
    actor.transport === "mobile"
    || Boolean(actor.currentSessionHash && webTargets.some((session) => session.token_hash === actor.currentSessionHash))
  );
  await writeAudit(actor.user.id, "account.sessions_revoked", { scope, revokedCount, currentSessionRevoked });
  return { schemaVersion: "1.0" as const, revokedCount, currentSessionRevoked };
}
