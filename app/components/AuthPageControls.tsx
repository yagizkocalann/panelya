"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";

export function AuthPageControls({ closeHref = "/" }: { closeHref?: string }) {
  const router = useRouter();
  return (
    <div className="auth-page-controls" aria-label="Sayfa kontrolleri">
      <button className="auth-back" type="button" onClick={() => window.history.length > 1 ? router.back() : router.push(closeHref)}>← Geri</button>
      <Link className="auth-close" href={closeHref} aria-label="Hesap ekranını kapat">×</Link>
    </div>
  );
}
