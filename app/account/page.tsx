import Link from "next/link";
import { redirect } from "next/navigation";
import { SiteFooter } from "../components/SiteFooter";
import { SiteHeader } from "../components/SiteHeader";
import { getCurrentUser } from "../lib/auth";
import { getBlockedUsers } from "../lib/reviews";

export const dynamic = "force-dynamic";

export default async function AccountPage({ searchParams }: { searchParams: Promise<{ error?: string; saved?: string; notice?: string; verified?: string; unblocked?: string }> }) {
  const user = await getCurrentUser();
  if (!user) redirect("/login?return_to=/account");
  const [query, blockedUsers] = await Promise.all([searchParams, getBlockedUsers(user.id)]);
  return <div className="site-shell"><SiteHeader />
    <main id="main-content" className="dashboard-main wrap">
      <div className="page-heading"><p className="section-kicker">Hesap merkezi</p><h1>{user.displayName}</h1><p>{user.role === "admin" ? "Studio yöneticisi" : "Okuyucu"} · {user.email}</p></div>
      {query.error && <p className="form-message form-message--error" role="alert">{query.error}</p>}
      {query.saved && <p className="form-message form-message--success" role="status">Değişiklik kaydedildi.</p>}
      {query.notice && <p className="form-message form-message--success" role="status">{query.notice}</p>}
      {query.verified && <p className="form-message form-message--success" role="status">E-posta adresin doğrulandı.</p>}
      {query.unblocked && <p className="form-message form-message--success" role="status">Kullanıcı engeli kaldırıldı.</p>}
      <section className={`verification-banner${user.emailVerifiedAt ? " is-verified" : ""}`}><div><span className="pill pill--accent">{user.emailVerifiedAt ? "Doğrulandı" : "Doğrulama bekliyor"}</span><h2>E-posta güvenliği</h2><p>{user.emailVerifiedAt ? `${user.email} doğrulandı.` : `${user.email} için gönderilen bağlantıyı Studio yerel e-posta kutusundan aç.`}</p></div>{!user.emailVerifiedAt && <form action="/api/auth/email-verification/request" method="post"><button className="button button--ghost" type="submit">Yeni bağlantı gönder</button></form>}</section>
      <div className="settings-grid">
        <section className="settings-card"><h2>Profil</h2><form className="stack-form" action="/api/account/profile" method="post"><label>Görünen ad<input name="display_name" defaultValue={user.displayName} minLength={2} maxLength={40} required /></label><button className="button button--primary" type="submit">Profili kaydet</button></form></section>
        <section className="settings-card"><h2>E-posta değiştir</h2><p>Yeni adres doğrulanmamış sayılır. Güvenlik için mevcut şifren gerekir ve diğer oturumların kapanır.</p><form className="stack-form" action="/api/account/email" method="post"><label>Yeni e-posta<input name="email" type="email" autoComplete="email" required /></label><label>Mevcut şifre<input name="current_password" type="password" autoComplete="current-password" required /></label><button className="button button--ghost" type="submit">E-postayı değiştir</button></form></section>
        <section className="settings-card"><h2>Şifre</h2><form className="stack-form" action="/api/account/password" method="post"><label>Mevcut şifre<input name="current_password" type="password" autoComplete="current-password" required /></label><label>Yeni şifre<input name="password" type="password" autoComplete="new-password" minLength={10} required /></label><label>Yeni şifre tekrarı<input name="password_confirmation" type="password" autoComplete="new-password" minLength={10} required /></label><button className="button button--ghost" type="submit">Şifreyi değiştir</button></form></section>
        <section className="settings-card"><h2>Oturumlar</h2><p>Bu cihazdan çık veya hesabın açık olduğu diğer yerel tarayıcı oturumlarını yönet.</p><div className="button-row"><Link className="button button--ghost" href="/account/sessions">Oturumları yönet</Link><form action="/api/auth/logout" method="post"><input type="hidden" name="return_to" value="/" /><button className="button button--ghost" type="submit">Çıkış yap</button></form></div></section>
        <section className="settings-card"><h2>Engellenen kullanıcılar</h2><p>Engellediğin kişilerle birbirinizin yorum ve yanıtlarını göremez, etkileşim kuramazsınız.</p>{blockedUsers.length ? <div className="blocked-user-list">{blockedUsers.map((blocked) => <article key={blocked.id}><div><strong>{blocked.display_name}</strong><small>{new Intl.DateTimeFormat("tr-TR", { dateStyle: "medium" }).format(new Date(blocked.created_at))} tarihinde engellendi</small></div><form action={`/api/blocks/${blocked.id}`} method="post"><input type="hidden" name="action" value="unblock" /><input type="hidden" name="return_to" value="/account" /><button className="button button--ghost" type="submit">Engeli kaldır</button></form></article>)}</div> : <p className="rating-only">Engellenen kullanıcı yok.</p>}</section>
        <section className="settings-card settings-card--danger"><h2>Hesabı sil</h2><p>Kütüphane, ilerleme ve oturumlar geri alınamaz biçimde silinir.</p><form className="stack-form" action="/api/account/delete" method="post"><label>Şifreyle doğrula<input name="password" type="password" autoComplete="current-password" required /></label><button className="button button--danger" type="submit">Hesabı kalıcı sil</button></form></section>
      </div>
    </main><SiteFooter /></div>;
}
