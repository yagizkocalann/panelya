"use client";

import Link from "next/link";
import { useEffect } from "react";
import { reportQualityEvent } from "./components/QualitySignals";

export default function ErrorPage({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  useEffect(() => {
    reportQualityEvent({ kind: "client_error", name: "route_error" });
  }, []);

  return <main className="error-recovery" id="main-content">
    <div className="error-recovery__card" role="alert">
      <p className="section-kicker">Bir şey ters gitti</p>
      <h1>Bu sayfa şu an açılamıyor.</h1>
      <p>Tekrar deneyebilir veya güvenli şekilde ana sayfaya dönebilirsin.</p>
      <div className="error-recovery__actions">
        <button className="button button--primary" type="button" onClick={reset}>Tekrar dene</button>
        <Link className="button button--ghost" href="/">Ana sayfaya dön</Link>
      </div>
    </div>
  </main>;
}
