import Link from "next/link";
import { redirect } from "next/navigation";
import { SiteHeader } from "../../components/SiteHeader";
import { RecentAuthenticationNotice, recentAuthenticationHref } from "../../components/RecentAuthenticationNotice";
import { getCurrentUser, hasRecentAuthentication } from "../../lib/auth";
import { getDatabase } from "../../lib/database";
import { getOutboxRetentionSummary } from "../../lib/notification-outbox";
import { notificationDeliveryMode } from "../../lib/runtime-config";
import { publicSiteUrlForCurrentRequest } from "../../lib/server-site-origins";

export const dynamic = "force-dynamic";
type OutboxRow = { id: string; recipient: string; kind: string; subject: string; body: string; action_url: string | null; status: "queued" | "opened"; created_at: number };
const kindLabels: Record<string, string> = { verify_email: "E-posta doğrulama", password_reset: "Şifre sıfırlama", security_notice: "Güvenlik bildirimi", new_episode: "Yeni bölüm" };

function notificationLabel(item: OutboxRow) {
  if (item.action_url) {
    try {
      if (new URL(item.action_url).pathname === "/accept-admin-invite") return "Yönetici daveti";
    } catch { /* Geçersiz URL açma endpointinde de reddedilir. */ }
  }
  return kindLabels[item.kind] ?? item.kind;
}

export default async function StudioOutboxPage({ searchParams }: { searchParams: Promise<{ error?: string; retention?: string; count?: string }> }) {
  const user = await getCurrentUser();
  if (!user) redirect("/login?return_to=/outbox");
  if (user.role !== "admin") redirect("/account?error=Studio%20yalnızca%20yönetici%20hesaplarına%20açık.");
  const db = await getDatabase();
  const [publicHome, rows, retention, deliveryMode, query, recentlyAuthenticated] = await Promise.all([
    publicSiteUrlForCurrentRequest("/"),
    db.prepare(`SELECT id, recipient, kind, subject, body, action_url, status, created_at
      FROM notification_outbox ORDER BY created_at DESC LIMIT 100`).all<OutboxRow>(),
    getOutboxRetentionSummary(),
    notificationDeliveryMode(),
    searchParams,
    hasRecentAuthentication(),
  ]);
  const deletedCount = Math.max(0, Number.parseInt(query.count ?? "0", 10) || 0);
  const formatter = new Intl.DateTimeFormat("tr-TR", { dateStyle: "medium", timeStyle: "short", timeZone: "Europe/Istanbul" });
  return <div className="site-shell studio-shell"><SiteHeader compact homeHref={publicHome} /><main id="main-content" className="studio-main wrap">
    <div className="studio-top"><div><p className="section-kicker">Bildirim teslimat sınırı</p><h1>E-posta kutusu</h1><p>Gerçek sağlayıcı bağlanana kadar doğrulama, sıfırlama, yönetici daveti, güvenlik ve yeni bölüm bildirimleri burada test edilir.</p></div><Link className="button button--ghost" href="/">← Studio</Link></div>
    <aside className="studio-notice"><strong>Aktif adaptör:</strong> {deliveryMode === "local_outbox" ? "Yerel D1 outbox" : `Tanımsız (${deliveryMode})`}. Bağlantılar loglara yazılmaz; production sağlayıcısı aynı vendor-bağımsız sözleşmeyi uygulayacak.</aside>
    {!recentlyAuthenticated && <RecentAuthenticationNotice returnTo="/outbox" />}
    {query.error && <p className="form-message form-message--error" role="alert">{query.error}</p>}
    {query.retention === "purged" && <p className="form-message form-message--success" role="status">Outbox bakımı tamamlandı; {deletedCount} süresi dolan kayıt silindi.</p>}

    <section className="studio-section outbox-retention" aria-labelledby="retention-title">
      <div className="section-heading"><div><p className="section-kicker">Politika v{retention.policyVersion}</p><h2 id="retention-title">Saklama ve veri minimizasyonu</h2></div><span className="sort-note">{retention.total} kayıt</span></div>
      <div className="outbox-retention__layout"><div className="outbox-retention__metrics"><article><span>Temizlenebilir</span><strong>{retention.purgeable}</strong></article><article><span>Aktif bağlantı</span><strong>{retention.queuedWithAction}</strong></article><article><span>En eski</span><strong>{retention.oldestCreatedAt ? formatter.format(retention.oldestCreatedAt) : "—"}</strong></article></div>
        <div className="outbox-retention__policy"><p>Açılmış kayıtlar 24 saat; sıradaki şifre sıfırlamalar 24 saat; doğrulama ve yönetici davetleri 48 saat; yeni bölüm bildirimleri 7 gün; bağlantısız güvenlik bildirimleri 30 gün tutulur.</p>
          {retention.purgeable > 0 ? recentlyAuthenticated ? <form action="/api/admin/outbox/retention" method="post"><input type="hidden" name="action" value="purge_expired" /><button className="button button--danger" type="submit">Süresi dolanları temizle</button></form> : <Link className="button button--ghost" href={recentAuthenticationHref("/outbox")}>Temizlik için şifreni doğrula</Link> : <p className="retention-current">Şu anda politika dışına çıkan kayıt yok.</p>}
        </div></div>
    </section>

    <section className="message-list" aria-label="Yerel e-postalar">{rows.results.length ? rows.results.map((item) => <article key={item.id} className={`message-card${item.status === "opened" ? " is-handled" : ""}`}><header><div><span className="pill pill--accent">{notificationLabel(item)}</span><strong>{item.subject}</strong><span>{item.recipient}</span></div><time dateTime={new Date(item.created_at).toISOString()}>{formatter.format(new Date(item.created_at))}</time></header><p>{item.body}</p>{item.action_url && <form action={`/api/admin/outbox/${item.id}/open`} method="post"><button className="button button--primary" type="submit">{item.status === "opened" ? "Bağlantıyı yeniden aç" : "Test bağlantısını aç"}</button></form>}</article>) : <div className="empty-state"><strong>Yerel e-posta kutusu boş.</strong><p>Yeni hesap oluştur, şifre sıfırlama isteği gönder veya yönetici daveti üret.</p><Link className="button button--primary" href="/users">Yönetici daveti oluştur</Link></div>}</section>
  </main></div>;
}
