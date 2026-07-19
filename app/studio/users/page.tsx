import Link from "next/link";
import { redirect } from "next/navigation";
import { SiteHeader } from "../../components/SiteHeader";
import { listAdminInvitations } from "../../lib/admin-invitations";
import { getCurrentUser } from "../../lib/auth";
import { publicSiteUrlForCurrentRequest } from "../../lib/server-site-origins";
import { listStudioUsers } from "../../lib/studio-admin";

export const dynamic = "force-dynamic";

const inviteMessages: Record<string, string> = {
  created: "Yönetici daveti oluşturuldu ve yerel e-posta kutusuna eklendi.",
  resent: "Davet bağlantısı yenilendi; önceki bağlantı artık geçersiz.",
  revoked: "Yönetici daveti iptal edildi.",
};

const inviteLabels = { pending: "Bekliyor", expired: "Süresi doldu", accepted: "Kabul edildi", revoked: "İptal edildi" } as const;

export default async function StudioUsersPage({ searchParams }: { searchParams: Promise<{ error?: string; updated?: string; invite?: string }> }) {
  const user = await getCurrentUser();
  if (!user) redirect("/login?return_to=/users");
  if (user.role !== "admin") redirect("/account?error=Studio%20yalnızca%20yönetici%20hesaplarına%20açık.");
  const [users, invitations, publicHome, query] = await Promise.all([
    listStudioUsers(),
    listAdminInvitations(),
    publicSiteUrlForCurrentRequest("/"),
    searchParams,
  ]);
  const adminCount = users.filter((item) => item.role === "admin").length;
  const formatter = new Intl.DateTimeFormat("tr-TR", { dateStyle: "medium", timeStyle: "short", timeZone: "Europe/Istanbul" });

  return <div className="site-shell studio-shell"><SiteHeader compact homeHref={publicHome} /><main id="main-content" className="studio-main wrap">
    <div className="studio-top"><div><p className="section-kicker">Erişim yönetimi</p><h1>Kullanıcılar ve roller</h1><p>Hesap rollerini yönet, yeni Studio yöneticileri davet et ve tek kullanımlık davetlerin durumunu izle.</p></div><div className="studio-top__actions"><Link className="button button--ghost" href="/">← Studio</Link><Link className="button button--ghost" href="/audit">Audit günlüğü</Link></div></div>
    <aside className="studio-notice"><strong>Güvenlik sınırı:</strong> Kendi rolünü değiştiremezsin ve son yönetici okuyucuya dönüştürülemez. Rol değişikliği hedef kullanıcının bütün oturumlarını kapatır. Davetler 24 saat geçerli ve tek kullanımlıktır.</aside>
    {query.error && <p className="form-message form-message--error" role="alert">{query.error}</p>}
    {query.updated && <p className="form-message form-message--success" role="status">Kullanıcı rolü güncellendi ve açık oturumları kapatıldı.</p>}
    {query.invite && inviteMessages[query.invite] && <p className="form-message form-message--success" role="status">{inviteMessages[query.invite]}</p>}

    <section className="studio-section admin-invite-section" aria-labelledby="invite-title">
      <div className="section-heading"><div><p className="section-kicker">Kontrollü yetkilendirme</p><h2 id="invite-title">Yönetici davetleri</h2></div><Link className="inline-link" href="/outbox">Yerel e-posta kutusu →</Link></div>
      <div className="admin-invite-layout">
        <form className="stack-form admin-invite-form" action="/api/admin/invitations" method="post">
          <h3>Yeni yönetici davet et</h3>
          <p>Hesabı olmayan bir e-posta adresine 24 saatlik, tek kullanımlık bağlantı gönder.</p>
          <label>E-posta<input name="email" type="email" autoComplete="email" maxLength={160} required /></label>
          <button className="button button--primary" type="submit">Davet oluştur</button>
        </form>
        <div className="admin-invite-list" aria-label="Yönetici davetleri">
          {invitations.length ? invitations.map((invitation) => <article key={invitation.id} className={`admin-invite-card admin-invite-card--${invitation.status}`}>
            <header><div><span className={`pill${invitation.status === "pending" ? " pill--accent" : ""}`}>{inviteLabels[invitation.status]}</span><strong>{invitation.email}</strong></div><time dateTime={new Date(invitation.updatedAt).toISOString()}>{formatter.format(invitation.updatedAt)}</time></header>
            <p>{invitation.status === "pending" ? `Bağlantı ${formatter.format(invitation.expiresAt)} tarihinde sona erer.` : invitation.status === "expired" ? "Bağlantı artık kullanılamaz; yenilersen önceki token geçersiz kalır." : invitation.status === "accepted" && invitation.acceptedAt ? `${formatter.format(invitation.acceptedAt)} tarihinde yönetici hesabına dönüştü.` : "Davet yönetici tarafından kapatıldı."}</p>
            <small>Davet eden: {invitation.invitedByName ?? "Kurulum yöneticisi"}</small>
            {(invitation.status === "pending" || invitation.status === "expired") && <div className="admin-invite-actions">
              <form action={`/api/admin/invitations/${invitation.id}`} method="post"><input type="hidden" name="action" value="resend" /><button className="button button--ghost" type="submit">Bağlantıyı yenile</button></form>
              <form action={`/api/admin/invitations/${invitation.id}`} method="post"><input type="hidden" name="action" value="revoke" /><button className="button button--danger" type="submit">Daveti iptal et</button></form>
            </div>}
          </article>) : <div className="inventory-empty"><div><strong>Henüz yönetici daveti yok.</strong><p>İlk davet oluşturulduğunda durumu burada görünür.</p></div></div>}
        </div>
      </div>
    </section>

    <section className="studio-section" aria-labelledby="users-title"><div className="section-heading"><div><p className="section-kicker">{adminCount} yönetici · {users.length - adminCount} okuyucu</p><h2 id="users-title">Hesap envanteri</h2></div><span className="sort-note">{users.length} hesap</span></div>
      <div className="admin-user-list">{users.map((item) => <article key={item.id}>
        <div className="admin-user-card__identity"><div className="inventory-status"><span className={`pill${item.role === "admin" ? " pill--accent" : ""}`}>{item.role === "admin" ? "Yönetici" : "Okuyucu"}</span><span className="pill">{item.emailVerifiedAt ? "Doğrulandı" : "Doğrulanmadı"}</span>{item.id === user.id && <span className="pill">Sen</span>}</div><strong>{item.displayName}</strong><a href={`mailto:${item.email}`}>{item.email}</a><small>Katılım: {formatter.format(item.createdAt)}</small></div>
        <dl className="admin-user-card__metrics"><div><dt>Oturum</dt><dd>{item.sessionCount}</dd></div><div><dt>Kütüphane</dt><dd>{item.libraryCount}</dd></div><div><dt>Yorum</dt><dd>{item.reviewCount}</dd></div></dl>
        <div className="admin-user-card__action">{item.id === user.id ? <p>Kendi rolün bu ekrandan değiştirilemez.</p> : <form action={`/api/admin/users/${item.id}/role`} method="post"><label>Platform rolü<select name="role" defaultValue={item.role}><option value="reader">Okuyucu</option><option value="admin">Yönetici</option></select></label><button className="button button--primary" type="submit">Rolü kaydet</button></form>}</div>
      </article>)}</div>
    </section>
  </main></div>;
}
