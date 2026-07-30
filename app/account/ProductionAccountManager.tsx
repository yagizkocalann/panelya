"use client";

import { FormEvent, useEffect, useState } from "react";
import {
  reauthenticationStorageKey,
  type PendingAccountAction,
  type PendingReauthentication,
} from "./reauthentication-state";

type CapabilityState = "enabled" | "reauthentication_required" | "provider_managed" | "unavailable";

type AccountOverview = {
  schemaVersion: "1.0";
  user: {
    id: string;
    displayName: string;
    email: string;
    emailVerified: boolean;
    role: "reader" | "admin";
    avatarUrl?: string;
  };
  provider: "database" | "google" | "apple";
  capabilities: {
    profileEditing: CapabilityState;
    avatarEditing: CapabilityState;
    emailChange: CapabilityState;
    passwordAction: CapabilityState;
    sessionManagement: CapabilityState;
    blockedAccounts: CapabilityState;
    accountDeletion: CapabilityState;
  };
};

type AccountSession = {
  id: string;
  deviceLabel: string;
  platform: "web" | "android" | "ios" | "unspecified";
  lastActiveAt: string;
  current: boolean;
  revocable: boolean;
};

type BlockedAccount = {
  id: string;
  displayName: string;
  avatarUrl?: string;
};

type DeletionSummary = {
  deleted: string[];
  anonymized: string[];
  retained: string[];
};

type AccountError = {
  error?: string;
  errorDescription?: string;
  reauthenticate?: boolean;
};

const deletionEffectLabels: Record<string, string> = {
  auth_identity: "Auth0 kimliği",
  profile: "Profil bilgileri",
  active_sessions: "Aktif oturumlar",
  library: "Kütüphane ve favoriler",
  reading_progress: "Okuma ilerlemesi",
  block_relationships: "Engelleme ilişkileri",
  community_contributions: "Yorum ve topluluk katkıları",
  legal_and_audit_records: "Yasal ve denetim kayıtları",
};

const platformLabels: Record<AccountSession["platform"], string> = {
  web: "Web",
  android: "Android",
  ios: "iOS",
  unspecified: "Bilinmeyen platform",
};

const providerLabels: Record<AccountOverview["provider"], string> = {
  database: "E-posta ve şifre",
  google: "Google",
  apple: "Apple",
};

function effectLabel(effect: string) {
  return deletionEffectLabels[effect] ?? effect.replaceAll("_", " ");
}

function base64Url(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

async function createPkce() {
  const verifier = base64Url(crypto.getRandomValues(new Uint8Array(32)));
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier));
  return { verifier, challenge: base64Url(new Uint8Array(digest)) };
}

async function accountRequest<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(path, {
    credentials: "same-origin",
    cache: "no-store",
    ...init,
    headers: {
      Accept: "application/json",
      ...(init?.body ? { "Content-Type": "application/json" } : {}),
      ...init?.headers,
    },
  });
  let value: unknown;
  try {
    value = await response.json();
  } catch {
    value = null;
  }
  if (!response.ok) {
    const error = value && typeof value === "object" ? value as AccountError : {};
    if (response.status === 401 && error.error === "not_authenticated") {
      window.location.assign("/login?return_to=/account");
    }
    throw new Error(error.errorDescription || "Hesap işlemi tamamlanamadı.");
  }
  return value as T;
}

function formatDate(value: string) {
  try {
    return new Intl.DateTimeFormat("tr-TR", {
      dateStyle: "medium",
      timeStyle: "short",
    }).format(new Date(value));
  } catch {
    return value;
  }
}

export function ProductionAccountManager() {
  const [overview, setOverview] = useState<AccountOverview | null>(null);
  const [sessions, setSessions] = useState<AccountSession[]>([]);
  const [blocks, setBlocks] = useState<BlockedAccount[]>([]);
  const [deletionSummary, setDeletionSummary] = useState<DeletionSummary | null>(null);
  const [displayName, setDisplayName] = useState("");
  const [newEmail, setNewEmail] = useState("");
  const [deletionText, setDeletionText] = useState("");
  const [deletionAcknowledged, setDeletionAcknowledged] = useState(false);
  const [message, setMessage] = useState<{ tone: "success" | "error"; text: string } | null>(null);
  const [busy, setBusy] = useState<string | null>("initial");

  useEffect(() => {
    let cancelled = false;
    Promise.all([
      accountRequest<AccountOverview>("/api/account"),
      accountRequest<{ sessions: AccountSession[] }>("/api/account/sessions"),
      accountRequest<{ accounts: BlockedAccount[] }>("/api/account/blocks"),
      accountRequest<DeletionSummary>("/api/account/deletion"),
    ]).then(([nextOverview, nextSessions, nextBlocks, nextSummary]) => {
      if (cancelled) return;
      setOverview(nextOverview);
      setDisplayName(nextOverview.user.displayName);
      setSessions(nextSessions.sessions);
      setBlocks(nextBlocks.accounts);
      setDeletionSummary(nextSummary);
      setBusy(null);
    }).catch((error: unknown) => {
      if (cancelled) return;
      setMessage({ tone: "error", text: error instanceof Error ? error.message : "Hesap bilgileri yüklenemedi." });
      setBusy(null);
    });
    return () => {
      cancelled = true;
    };
  }, []);

  async function runAction(key: string, action: () => Promise<void>) {
    setBusy(key);
    setMessage(null);
    try {
      await action();
    } catch (error) {
      setMessage({ tone: "error", text: error instanceof Error ? error.message : "İşlem tamamlanamadı." });
    } finally {
      setBusy(null);
    }
  }

  async function beginReauthentication(
    purpose: PendingReauthentication["purpose"],
    action: PendingAccountAction,
  ) {
    await runAction(`reauth-${purpose}`, async () => {
      const { verifier, challenge } = await createPkce();
      const redirectUri = new URL("/account/reauthentication/callback", window.location.origin).toString();
      const started = await accountRequest<{
        requestId: string;
        authorizationUrl: string;
        expiresAt: string;
      }>("/api/account/reauthentication/start", {
        method: "POST",
        body: JSON.stringify({
          purpose,
          redirectUri,
          codeChallenge: challenge,
          codeChallengeMethod: "S256",
        }),
      });
      const authorizationUrl = new URL(started.authorizationUrl);
      const state = authorizationUrl.searchParams.get("state");
      if (!state || authorizationUrl.protocol !== "https:") {
        throw new Error("Kimlik doğrulama adresi doğrulanamadı.");
      }
      const pending: PendingReauthentication = {
        requestId: started.requestId,
        codeVerifier: verifier,
        redirectUri,
        purpose,
        action,
        createdAt: Date.now(),
      };
      sessionStorage.setItem(reauthenticationStorageKey(state), JSON.stringify(pending));
      window.location.assign(authorizationUrl.toString());
    });
  }

  async function updateProfile(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await runAction("profile", async () => {
      const next = await accountRequest<AccountOverview>("/api/account/profile", {
        method: "PATCH",
        body: JSON.stringify({ displayName }),
      });
      setOverview(next);
      setDisplayName(next.user.displayName);
      setMessage({ tone: "success", text: "Profil bilgilerin kaydedildi." });
    });
  }

  async function requestPasswordReset() {
    await runAction("password", async () => {
      await accountRequest("/api/account/password-reset", {
        method: "POST",
        body: JSON.stringify({}),
      });
      setMessage({ tone: "success", text: "Şifre yenileme bağlantısı e-posta adresine gönderildi." });
    });
  }

  async function refreshSessions() {
    const value = await accountRequest<{ sessions: AccountSession[] }>("/api/account/sessions");
    setSessions(value.sessions);
  }

  async function revokeSession(session: AccountSession) {
    await runAction(`session-${session.id}`, async () => {
      const result = await accountRequest<{ currentSessionRevoked: boolean }>(
        `/api/account/sessions/${encodeURIComponent(session.id)}`,
        { method: "DELETE" },
      );
      if (result.currentSessionRevoked) {
        window.location.assign("/login?notice=Oturum%20kapatıldı.");
        return;
      }
      await refreshSessions();
      setMessage({ tone: "success", text: "Seçilen oturum kapatıldı." });
    });
  }

  async function revokeOtherSessions() {
    await runAction("sessions-others", async () => {
      await accountRequest("/api/account/sessions/revoke", {
        method: "POST",
        body: JSON.stringify({ scope: "others" }),
      });
      await refreshSessions();
      setMessage({ tone: "success", text: "Diğer tüm oturumlar kapatıldı." });
    });
  }

  async function unblockAccount(account: BlockedAccount) {
    await runAction(`block-${account.id}`, async () => {
      await accountRequest(`/api/account/blocks/${encodeURIComponent(account.id)}`, { method: "DELETE" });
      setBlocks((current) => current.filter((item) => item.id !== account.id));
      setMessage({ tone: "success", text: `${account.displayName} için engel kaldırıldı.` });
    });
  }

  if (busy === "initial") {
    return <section className="settings-card account-loading" aria-live="polite">
      <h2>Hesap bilgileri hazırlanıyor</h2>
      <p>Profil ve güvenlik ayarların yükleniyor.</p>
    </section>;
  }

  if (!overview) {
    return <section className="settings-card settings-card--danger">
      <h2>Hesap bilgileri açılamadı</h2>
      <p>{message?.text ?? "Sayfayı yenileyip tekrar deneyebilirsin."}</p>
      <button className="button button--ghost" type="button" onClick={() => window.location.reload()}>Tekrar dene</button>
    </section>;
  }

  const otherRevocableSessions = sessions.filter((session) => !session.current && session.revocable);
  const emailManagedByProvider = overview.capabilities.emailChange === "provider_managed";
  const passwordManagedByProvider = overview.capabilities.passwordAction === "provider_managed";
  const deletionReady = deletionAcknowledged && deletionText.trim().toLocaleUpperCase("tr-TR") === "HESABIMI SİL";

  return <>
    <section className="account-overview" aria-label="Hesap özeti">
      <div>
        <span className="pill pill--accent">{providerLabels[overview.provider]}</span>
        <h2>{overview.user.displayName}</h2>
        <p>{overview.user.email} · {overview.user.emailVerified ? "Doğrulanmış e-posta" : "Doğrulama bekliyor"}</p>
      </div>
      <form action="/api/auth/logout" method="post">
        <input type="hidden" name="return_to" value="/" />
        <button className="button button--ghost" type="submit">Çıkış yap</button>
      </form>
    </section>

    {message && <p
      className={`form-message form-message--${message.tone}`}
      role={message.tone === "error" ? "alert" : "status"}
    >{message.text}</p>}

    <div className="settings-grid">
      <section className="settings-card">
        <h2>Profil</h2>
        <p>Toplulukta ve hesap alanlarında görünen adını düzenle.</p>
        <form className="stack-form" onSubmit={updateProfile}>
          <label>Görünen ad
            <input
              value={displayName}
              onChange={(event) => setDisplayName(event.target.value)}
              minLength={2}
              maxLength={80}
              required
            />
          </label>
          <button className="button button--primary" type="submit" disabled={busy === "profile"}>
            {busy === "profile" ? "Kaydediliyor…" : "Profili kaydet"}
          </button>
        </form>
      </section>

      <section className="settings-card">
        <h2>E-posta ve şifre</h2>
        {emailManagedByProvider
          ? <p>E-posta adresin {providerLabels[overview.provider]} hesabın tarafından yönetiliyor.</p>
          : <form
              className="stack-form"
              onSubmit={(event) => {
                event.preventDefault();
                void beginReauthentication("email_change", { kind: "email_change", newEmail: newEmail.trim() });
              }}
            >
              <label>Yeni e-posta
                <input
                  type="email"
                  autoComplete="email"
                  value={newEmail}
                  onChange={(event) => setNewEmail(event.target.value)}
                  required
                />
              </label>
              <button className="button button--ghost" type="submit" disabled={busy === "reauth-email_change"}>
                {busy === "reauth-email_change" ? "Yönlendiriliyor…" : "E-postayı doğrulayarak değiştir"}
              </button>
            </form>}
        {passwordManagedByProvider
          ? <p>Şifre ve giriş güvenliği {providerLabels[overview.provider]} hesabından yönetilir.</p>
          : <div className="account-inline-action">
              <p>Şifre Panelya tarafından alınmaz. Auth0 güvenli yenileme bağlantısını e-posta ile gönderir.</p>
              <button
                className="button button--ghost"
                type="button"
                onClick={() => void requestPasswordReset()}
                disabled={busy === "password"}
              >{busy === "password" ? "Gönderiliyor…" : "Şifre yenileme bağlantısı gönder"}</button>
            </div>}
      </section>

      <section className="settings-card settings-card--wide">
        <div className="account-card-heading">
          <div><h2>Aktif oturumlar</h2><p>Web ve mobil cihazlarda hesabına erişebilen oturumları incele.</p></div>
          {otherRevocableSessions.length > 0 && <button
            className="button button--ghost"
            type="button"
            onClick={() => void revokeOtherSessions()}
            disabled={busy === "sessions-others"}
          >{busy === "sessions-others" ? "Kapatılıyor…" : "Diğer oturumları kapat"}</button>}
        </div>
        <div className="account-session-list">
          {sessions.map((session) => <article key={session.id}>
            <div>
              <div className="inventory-status">
                <span className={`pill${session.current ? " pill--accent" : ""}`}>{session.current ? "Bu cihaz" : "Aktif"}</span>
                <span className="pill">{platformLabels[session.platform]}</span>
              </div>
              <strong>{session.deviceLabel}</strong>
              <small>Son etkinlik: {formatDate(session.lastActiveAt)}</small>
            </div>
            {session.revocable && !session.current && <button
              className="button button--ghost"
              type="button"
              onClick={() => void revokeSession(session)}
              disabled={busy === `session-${session.id}`}
            >{busy === `session-${session.id}` ? "Kapatılıyor…" : "Oturumu kapat"}</button>}
          </article>)}
        </div>
      </section>

      <section className="settings-card">
        <h2>Engellenen hesaplar</h2>
        <p>Engellediğin hesapların yorumları ve yanıtları karşılıklı olarak gizlenir.</p>
        {blocks.length > 0
          ? <div className="blocked-user-list">{blocks.map((account) => <article key={account.id}>
              <div><strong>{account.displayName}</strong><small>Engellenmiş hesap</small></div>
              <button
                className="button button--ghost"
                type="button"
                onClick={() => void unblockAccount(account)}
                disabled={busy === `block-${account.id}`}
              >{busy === `block-${account.id}` ? "Kaldırılıyor…" : "Engeli kaldır"}</button>
            </article>)}</div>
          : <p className="rating-only">Engellenen hesap yok.</p>}
      </section>

      <section className="settings-card settings-card--danger">
        <h2>Hesabı sil</h2>
        <p>Bu işlem geri alınamaz. Önce nelerin silineceğini, anonimleştirileceğini ve yasal nedenle saklanacağını incele.</p>
        {deletionSummary && <div className="deletion-effects">
          <div><strong>Silinir</strong><ul>{deletionSummary.deleted.map((effect) => <li key={effect}>{effectLabel(effect)}</li>)}</ul></div>
          <div><strong>Anonimleştirilir</strong><ul>{deletionSummary.anonymized.map((effect) => <li key={effect}>{effectLabel(effect)}</li>)}</ul></div>
          <div><strong>Saklanır</strong><ul>{deletionSummary.retained.map((effect) => <li key={effect}>{effectLabel(effect)}</li>)}</ul></div>
        </div>}
        <form
          className="stack-form"
          onSubmit={(event) => {
            event.preventDefault();
            if (!deletionReady) {
              setMessage({ tone: "error", text: "Hesap silme onaylarını tamamlamalısın." });
              return;
            }
            void beginReauthentication("account_deletion", {
              kind: "account_deletion",
              idempotencyKey: crypto.randomUUID(),
            });
          }}
        >
          <label className="check-row">
            <input
              type="checkbox"
              checked={deletionAcknowledged}
              onChange={(event) => setDeletionAcknowledged(event.target.checked)}
            />
            Silme, anonimleştirme ve saklama etkilerini okudum.
          </label>
          <label>Onaylamak için “HESABIMI SİL” yaz
            <input value={deletionText} onChange={(event) => setDeletionText(event.target.value)} required />
          </label>
          <button
            className="button button--danger"
            type="submit"
            disabled={!deletionReady || busy === "reauth-account_deletion"}
          >{busy === "reauth-account_deletion" ? "Yönlendiriliyor…" : "Kimliğimi doğrula ve hesabı sil"}</button>
        </form>
      </section>
    </div>
  </>;
}
