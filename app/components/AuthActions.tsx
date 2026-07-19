"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

type SessionState =
  | { status: "loading" }
  | { status: "anonymous" }
  | { status: "authenticated"; user: { displayName: string; role: "reader" | "admin" } };

export function AuthActions({ compact = false, studioHref = "/studio" }: { compact?: boolean; studioHref?: string }) {
  const [session, setSession] = useState<SessionState>({ status: "loading" });

  useEffect(() => {
    let active = true;
    fetch("/api/auth/me", { credentials: "same-origin", cache: "no-store" })
      .then((response) => response.json())
      .then((data) => {
        if (!active) return;
        setSession(data.authenticated ? { status: "authenticated", user: data.user } : { status: "anonymous" });
      })
      .catch(() => active && setSession({ status: "anonymous" }));
    return () => { active = false; };
  }, []);

  if (session.status === "authenticated") {
    return <>
      {!compact && <Link className="text-link library-nav-link" href="/library" aria-label="Kütüphanem"><span aria-hidden="true">▤</span><span className="library-nav-link__label">Kütüphanem</span></Link>}
      {session.user.role === "admin" && !compact && <Link className="text-link" href={studioHref}>Studio</Link>}
      <Link className="button button--ghost account-chip" href="/account">{session.user.displayName}</Link>
    </>;
  }

  if (session.status === "loading") return <span className="auth-loading" aria-label="Hesap bilgisi yükleniyor">•••</span>;

  return <>
    <Link className="button button--ghost" href="/login">Giriş</Link>
    {!compact && <Link className="button button--primary" href="/register">Üye ol</Link>}
  </>;
}
