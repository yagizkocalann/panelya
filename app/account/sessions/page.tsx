import Link from "next/link";
import { redirect } from "next/navigation";
import { SiteFooter } from "../../components/SiteFooter";
import { SiteHeader } from "../../components/SiteHeader";
import { getCurrentUser } from "../../lib/auth";
import { listCurrentUserSessions } from "../../lib/sessions";

export const dynamic = "force-dynamic";

function deviceLabel(userAgent: string | null) {
  if (!userAgent) return "Bilinmeyen tarayıcı";
  if (/mobile|android|iphone/i.test(userAgent)) return "Mobil tarayıcı";
  return "Masaüstü tarayıcı";
}

export default async function SessionsPage({ searchParams }: { searchParams: Promise<{ error?: string; notice?: string }> }) {
  const user = await getCurrentUser();
  if (!user) redirect("/login?return_to=/account/sessions");
  const [sessions, query] = await Promise.all([listCurrentUserSessions(), searchParams]);
  const otherCount = sessions.filter((session) => !session.isCurrent).length;
  return <div className="site-shell"><SiteHeader /><main id="main-content" className="dashboard-main wrap">
    <div className="studio-top"><div><p className="section-kicker">Hesap güvenliği</p><h1>Aktif oturumlar</h1><p>Bu hesaba erişebilen yerel tarayıcı oturumlarını incele ve kapat.</p></div><Link className="button button--ghost" href="/account">← Hesaba dön</Link></div>
    {query.error && <p className="form-message form-message--error" role="alert">{query.error}</p>}{query.notice && <p className="form-message form-message--success" role="status">{query.notice}</p>}
    {otherCount > 0 && <form className="session-toolbar" action="/api/account/sessions/revoke-others" method="post"><button className="button button--ghost" type="submit">Diğer tüm oturumları kapat</button></form>}
    <section className="session-list" aria-label="Aktif oturumlar">{sessions.map((session) => <article className="session-card" key={session.tokenHash}><div><div className="inventory-status"><span className={`pill${session.isCurrent ? " pill--accent" : ""}`}>{session.isCurrent ? "Bu cihaz" : "Aktif"}</span><span className="pill">{session.scope === "studio" ? "Studio" : "Okuyucu"}</span></div><h2>{deviceLabel(session.userAgent)}</h2><p>{session.userAgent?.slice(0, 130) ?? "Tarayıcı bilgisi gönderilmedi."}</p><small>Son etkinlik: {new Intl.DateTimeFormat("tr-TR", { dateStyle: "medium", timeStyle: "short" }).format(new Date(session.lastSeenAt))} · Boşta kalma sınırı: {new Intl.DateTimeFormat("tr-TR", { timeStyle: "short" }).format(new Date(session.idleExpiresAt))} · En geç: {new Intl.DateTimeFormat("tr-TR", { dateStyle: "medium" }).format(new Date(session.expiresAt))}</small></div>{!session.isCurrent && <form action="/api/account/sessions/revoke" method="post"><input type="hidden" name="token_hash" value={session.tokenHash} /><button className="button button--ghost" type="submit">Oturumu kapat</button></form>}</article>)}</section>
  </main><SiteFooter /></div>;
}
