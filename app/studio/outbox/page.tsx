import Link from "next/link";
import { redirect } from "next/navigation";
import { SiteHeader } from "../../components/SiteHeader";
import { getCurrentUser } from "../../lib/auth";
import { getDatabase } from "../../lib/database";
import { publicSiteUrlForCurrentRequest } from "../../lib/server-site-origins";

export const dynamic = "force-dynamic";
type OutboxRow = { id: string; recipient: string; kind: string; subject: string; body: string; action_url: string | null; status: "queued" | "opened"; created_at: number };
const kindLabels: Record<string, string> = { verify_email: "E-posta doğrulama", password_reset: "Şifre sıfırlama", security_notice: "Güvenlik bildirimi" };

function notificationLabel(item: OutboxRow) {
  if (item.action_url) {
    try {
      if (new URL(item.action_url).pathname === "/accept-admin-invite") return "Yönetici daveti";
    } catch { /* Geçersiz URL açma endpointinde de reddedilir. */ }
  }
  return kindLabels[item.kind] ?? item.kind;
}

export default async function StudioOutboxPage() {
  const user = await getCurrentUser();
  if (!user) redirect("/login?return_to=/outbox");
  if (user.role !== "admin") redirect("/account?error=Studio%20yalnızca%20yönetici%20hesaplarına%20açık.");
  const publicHome = await publicSiteUrlForCurrentRequest("/");
  const db = await getDatabase();
  const rows = await db.prepare(`SELECT id, recipient, kind, subject, body, action_url, status, created_at
    FROM notification_outbox ORDER BY created_at DESC LIMIT 100`).all<OutboxRow>();
  return <div className="site-shell studio-shell"><SiteHeader compact homeHref={publicHome} /><main id="main-content" className="studio-main wrap">
    <div className="studio-top"><div><p className="section-kicker">Yerel servis adaptörü</p><h1>E-posta kutusu</h1><p>Gerçek sağlayıcı bağlanana kadar doğrulama, sıfırlama, yönetici daveti ve güvenlik bildirimleri burada test edilir.</p></div><Link className="button button--ghost" href="/">← Studio</Link></div>
    <aside className="studio-notice"><strong>Yalnızca yerel:</strong> Bu ekran production e-posta sağlayıcısının yerine geçen D1 outbox adaptörüdür. Bağlantılar loglara yazılmaz.</aside>
    <section className="message-list" aria-label="Yerel e-postalar">{rows.results.length ? rows.results.map((item) => <article key={item.id} className={`message-card${item.status === "opened" ? " is-handled" : ""}`}><header><div><span className="pill pill--accent">{notificationLabel(item)}</span><strong>{item.subject}</strong><span>{item.recipient}</span></div><time dateTime={new Date(item.created_at).toISOString()}>{new Intl.DateTimeFormat("tr-TR", { dateStyle: "medium", timeStyle: "short" }).format(new Date(item.created_at))}</time></header><p>{item.body}</p>{item.action_url && <form action={`/api/admin/outbox/${item.id}/open`} method="post"><button className="button button--primary" type="submit">{item.status === "opened" ? "Bağlantıyı yeniden aç" : "Test bağlantısını aç"}</button></form>}</article>) : <div className="empty-state"><strong>Yerel e-posta kutusu boş.</strong><p>Yeni hesap oluştur, şifre sıfırlama isteği gönder veya yönetici daveti üret.</p><Link className="button button--primary" href="/users">Yönetici daveti oluştur</Link></div>}</section>
  </main></div>;
}
