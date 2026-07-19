import Link from "next/link";
import { AuthPageControls } from "../components/AuthPageControls";
import { SiteHeader } from "../components/SiteHeader";
import { inspectAdminInvitation } from "../lib/admin-invitations";

export const dynamic = "force-dynamic";
export const metadata = {
  title: "Studio davetini kabul et | Panelya",
  robots: { index: false, follow: false },
  referrer: "no-referrer" as const,
};

export default async function AcceptAdminInvitePage({ searchParams }: { searchParams: Promise<{ token?: string; error?: string }> }) {
  const query = await searchParams;
  const token = query.token ?? "";
  const invitation = await inspectAdminInvitation(token);

  return <div className="site-shell auth-shell"><SiteHeader compact /><main id="main-content" className="auth-main"><AuthPageControls closeHref="/login" />
    <section className="auth-card"><p className="section-kicker">Panelya Studio</p><h1>Yönetici daveti</h1>
      {query.error && <p className="form-message form-message--error" role="alert">{query.error}</p>}
      {invitation ? <>
        <p><strong>{invitation.email}</strong> adresi için yönetici hesabını oluştur. Davet tek kullanımlıktır ve kabul edildiğinde bu tarayıcıda Studio oturumu açılır.</p>
        <aside className="auth-role-notice"><strong>Yetki kapsamı:</strong> Yönetici rolü içerik, kullanıcı, moderasyon ve yayın ayarlarını değiştirebilir.</aside>
        <form className="stack-form" action="/api/auth/admin-invitation/accept" method="post">
          <input type="hidden" name="token" value={token} />
          <label>Görünen ad<input name="display_name" autoComplete="name" minLength={2} maxLength={40} required /></label>
          <label>Şifre<input name="password" type="password" autoComplete="new-password" minLength={10} required /><small>En az 10 karakter; bir harf ve bir rakam.</small></label>
          <label>Şifre tekrarı<input name="password_confirmation" type="password" autoComplete="new-password" minLength={10} required /></label>
          <label className="check-row"><input name="terms" type="checkbox" value="accepted" required /> <span><Link href="/terms">Kullanım koşullarını</Link> kabul ediyorum.</span></label>
          <button className="button button--primary button--large" type="submit">Daveti kabul et</button>
        </form>
      </> : <>
        <p>Davet bağlantısı geçersiz, kullanılmış veya süresi dolmuş.</p>
        <Link className="button button--primary" href="/login">Studio girişine dön</Link>
      </>}
    </section>
  </main></div>;
}
