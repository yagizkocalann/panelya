"use client";

import { useEffect, useRef, useState } from "react";
import {
  reauthenticationStorageKey,
  type PendingReauthentication,
} from "../../reauthentication-state";

type Props = {
  authorizationCode?: string;
  state?: string;
  providerError?: string;
};

type AccountError = {
  errorDescription?: string;
};

async function jsonRequest<T>(path: string, init: RequestInit): Promise<T> {
  const response = await fetch(path, {
    credentials: "same-origin",
    cache: "no-store",
    ...init,
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      ...init.headers,
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
    throw new Error(error.errorDescription || "Hesap işlemi tamamlanamadı.");
  }
  return value as T;
}

function accountLocation(kind: "success" | "error", message: string) {
  const query = new URLSearchParams({ [kind === "success" ? "notice" : "error"]: message });
  return `/account?${query.toString()}`;
}

export function ReauthenticationCallbackClient({ authorizationCode, state, providerError }: Props) {
  const started = useRef(false);
  const [status, setStatus] = useState("Kimlik doğrulama sonucu kontrol ediliyor…");

  useEffect(() => {
    if (started.current) return;
    started.current = true;
    window.history.replaceState(null, "", "/account/reauthentication/callback");

    async function complete() {
      if (providerError) throw new Error("Kimlik doğrulama tamamlanmadı.");
      if (!authorizationCode || !state) throw new Error("Kimlik doğrulama cevabı eksik.");
      const key = reauthenticationStorageKey(state);
      const stored = sessionStorage.getItem(key);
      sessionStorage.removeItem(key);
      if (!stored) throw new Error("Kimlik doğrulama isteği bulunamadı veya süresi doldu.");

      let pending: PendingReauthentication;
      try {
        pending = JSON.parse(stored) as PendingReauthentication;
      } catch {
        throw new Error("Kimlik doğrulama isteği okunamadı.");
      }
      if (!pending.requestId
        || !pending.codeVerifier
        || !pending.redirectUri
        || Date.now() - pending.createdAt > 10 * 60 * 1000) {
        throw new Error("Kimlik doğrulama isteğinin süresi doldu.");
      }

      setStatus("Tek kullanımlık güvenlik kanıtı hazırlanıyor…");
      const completed = await jsonRequest<{
        purpose: PendingReauthentication["purpose"];
        reauthenticationToken: string;
      }>("/api/account/reauthentication/complete", {
        method: "POST",
        body: JSON.stringify({
          requestId: pending.requestId,
          authorizationCode,
          state,
          codeVerifier: pending.codeVerifier,
          redirectUri: pending.redirectUri,
        }),
      });
      if (completed.purpose !== pending.purpose) throw new Error("Kimlik doğrulama amacı eşleşmiyor.");

      if (pending.action.kind === "email_change") {
        setStatus("E-posta değişikliği uygulanıyor…");
        await jsonRequest("/api/account/email-change", {
          method: "POST",
          body: JSON.stringify({
            newEmail: pending.action.newEmail,
            reauthenticationToken: completed.reauthenticationToken,
          }),
        });
        window.location.replace(accountLocation("success", "E-posta değişikliği kabul edildi."));
        return;
      }

      setStatus("Hesap silme isteği güvenli biçimde başlatılıyor…");
      await jsonRequest("/api/account/deletion", {
        method: "POST",
        headers: { "Idempotency-Key": pending.action.idempotencyKey },
        body: JSON.stringify({
          confirmation: "delete_my_account",
          reauthenticationToken: completed.reauthenticationToken,
        }),
      });
      await fetch("/api/auth/logout", {
        method: "POST",
        credentials: "same-origin",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: "return_to=%2F",
      });
      window.location.replace("/?account_deleted=1");
    }

    void complete().catch((error: unknown) => {
      const message = error instanceof Error ? error.message : "Kimlik doğrulama tamamlanamadı.";
      setStatus(message);
      window.setTimeout(() => window.location.replace(accountLocation("error", message)), 900);
    });
  }, [authorizationCode, providerError, state]);

  return <div className="auth-shell">
    <main id="main-content" className="auth-card auth-card--compact" aria-live="polite">
      <p className="section-kicker">Hesap güvenliği</p>
      <h1>Kimlik doğrulanıyor</h1>
      <p>{status}</p>
      <noscript>Bu işlem için JavaScript etkin olmalıdır.</noscript>
    </main>
  </div>;
}
