import Link from "next/link";
import { redirect } from "next/navigation";
import { SiteHeader } from "../../components/SiteHeader";
import { getCurrentUser } from "../../lib/auth";
import { publicSiteUrlForCurrentRequest } from "../../lib/server-site-origins";
import { listStudioUsers } from "../../lib/studio-admin";

export const dynamic = "force-dynamic";

export default async function StudioUsersPage({ searchParams }: { searchParams: Promise<{ error?: string; updated?: string }> }) {
  const user = await getCurrentUser();
  if (!user) redirect("/login?return_to=/users");
  if (user.role !== "admin") redirect("/account?error=Studio%20yalnızca%20yönetici%20hesaplarına%20açık.");
  const [users, publicHome, query] = await Promise.all([listStudioUsers(), publicSiteUrlForCurrentRequest("/"), searchParams]);
  const adminCount = users.filter((item) => item.role === "admin").length;
  const formatter = new Intl.DateTimeFormat("tr-TR", { dateStyle: "medium", timeStyle: "short", timeZone: "Europe/Istanbul" });

  return <div className="site-shell studio-shell"><SiteHeader compact homeHref={publicHome} /><main id="main-content" className="studio-main wrap">
    <div className="studio-top"><div><p className="section-kicker">Erişim yönetimi</p><h1>Kullanıcılar ve roller</h1><p>Yerel hesapların platform rolünü, doğrulama durumunu ve etkin oturumlarını yönet.</p></div><div className="studio-top__actions"><Link className="button button--ghost" href="/">← Studio</Link><Link className="button button--ghost" href="/audit">Audit günlüğü</Link></div></div>
    <aside className="studio-notice"><strong>Güvenlik sınırı:</strong> Kendi rolünü değiştiremezsin ve son yönetici okuyucuya dönüştürülemez. Rol değişikliği hedef kullanıcının bütün oturumlarını kapatır.</aside>
    {query.error && <p className="form-message form-message--error" role="alert">{query.error}</p>}
    {query.updated && <p className="form-message form-message--success" role="status">Kullanıcı rolü güncellendi ve açık oturumları kapatıldı.</p>}
    <section className="studio-section" aria-labelledby="users-title"><div className="section-heading"><div><p className="section-kicker">{adminCount} yönetici · {users.length - adminCount} okuyucu</p><h2 id="users-title">Hesap envanteri</h2></div><span className="sort-note">{users.length} hesap</span></div>
      <div className="admin-user-list">{users.map((item) => <article key={item.id}>
        <div className="admin-user-card__identity"><div className="inventory-status"><span className={`pill${item.role === "admin" ? " pill--accent" : ""}`}>{item.role === "admin" ? "Yönetici" : "Okuyucu"}</span><span className="pill">{item.emailVerifiedAt ? "Doğrulandı" : "Doğrulanmadı"}</span>{item.id === user.id && <span className="pill">Sen</span>}</div><strong>{item.displayName}</strong><a href={`mailto:${item.email}`}>{item.email}</a><small>Katılım: {formatter.format(item.createdAt)}</small></div>
        <dl className="admin-user-card__metrics"><div><dt>Oturum</dt><dd>{item.sessionCount}</dd></div><div><dt>Kütüphane</dt><dd>{item.libraryCount}</dd></div><div><dt>Yorum</dt><dd>{item.reviewCount}</dd></div></dl>
        <div className="admin-user-card__action">{item.id === user.id ? <p>Kendi rolün bu ekrandan değiştirilemez.</p> : <form action={`/api/admin/users/${item.id}/role`} method="post"><label>Platform rolü<select name="role" defaultValue={item.role}><option value="reader">Okuyucu</option><option value="admin">Yönetici</option></select></label><button className="button button--primary" type="submit">Rolü kaydet</button></form>}</div>
      </article>)}</div>
    </section>
  </main></div>;
}
