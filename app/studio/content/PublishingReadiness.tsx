import type { PublishingReadiness } from "../../lib/publishing-readiness";

const labels = { ready: "Hazır", warning: "Uyarı", blocking: "Eksik" } as const;

export function PublishingReadinessSummary({ readiness, title = "Yayın öncesi doğrulama" }: { readiness: PublishingReadiness; title?: string }) {
  return <section className="publishing-readiness" aria-labelledby="publishing-readiness-title">
    <header>
      <div><p className="section-kicker">Güvenli yayınlama</p><h2 id="publishing-readiness-title">{title}</h2></div>
      <strong className={`publishing-readiness__result publishing-readiness__result--${readiness.ready ? "ready" : "blocking"}`}>
        {readiness.ready ? "Yayına hazır" : `${readiness.blocking.length} engel var`}
      </strong>
    </header>
    <ul className="publishing-readiness__list">
      {readiness.checks.map((check) => <li key={check.id} className={`publishing-readiness__item publishing-readiness__item--${check.status}`}>
        <span aria-hidden="true">{check.status === "ready" ? "✓" : check.status === "warning" ? "!" : "×"}</span>
        <div><strong>{check.label}</strong><p>{check.detail}</p></div>
        <small>{labels[check.status]}</small>
      </li>)}
    </ul>
    <p className="publishing-readiness__note">Yayın isteği gönderildiğinde kritik kurallar sunucuda güncel veriyle tekrar kontrol edilir.</p>
  </section>;
}
