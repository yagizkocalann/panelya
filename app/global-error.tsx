"use client";

import Link from "next/link";
import { useEffect } from "react";
import { reportQualityEvent } from "./components/QualitySignals";

export default function GlobalError({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  useEffect(() => {
    reportQualityEvent({ kind: "client_error", name: "route_error" });
  }, []);

  return <html lang="tr"><body><main className="error-recovery" id="main-content">
    <div className="error-recovery__card" role="alert">
      <p className="section-kicker">Panelya</p>
      <h1>Uygulama yüklenemedi.</h1>
      <p>Bağlantını kontrol edip yeniden deneyebilirsin.</p>
      <div className="error-recovery__actions">
        <button className="button button--primary" type="button" onClick={reset}>Yeniden yükle</button>
        <Link className="button button--ghost" href="/">Ana sayfaya dön</Link>
      </div>
    </div>
  </main></body></html>;
}
