import Link from "next/link";
import { AuthPageControls } from "../components/AuthPageControls";
import { SiteHeader } from "../components/SiteHeader";
import { hasAdminAccount } from "../lib/admin-invitations";
import { adminBootstrapToken } from "../lib/runtime-config";

export const dynamic = "force-dynamic";
export const metadata = {
  title: "İlk Studio yöneticisi | Panelya",
  robots: { index: false, follow: false },
  referrer: "no-referrer" as const,
};

export default async function BootstrapAdminPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const configured = (await adminBootstrapToken()).length >= 32;
  const [query, hasAdmin] = await Promise.all([searchParams, hasAdminAccount().catch(() => false)]);

  return <div className="site-shell auth-shell"><SiteHeader compact /><main id="main-content" className="auth-main"><AuthPageControls closeHref="/login" />
    <section className="auth-card"><p className="section-kicker">Tek seferlik kurulum</p><h1>İlk Studio yöneticisi</h1>
      {query.error && <p className="form-message form-message--error" role="alert">{query.error}</p>}
      {!hasAdmin && configured ? <>
        <p>Bu form yalnızca hiç yönetici hesabı bulunmayan kurulumda çalışır. Dağıtım sırrı doğrulandıktan sonra ilk yönetici oluşturulur ve akış kalıcı olarak kapanır.</p>
        <form className="stack-form" action="/api/auth/admin-bootstrap" method="post">
          <label>Görünen ad<input name="display_name" autoComplete="name" minLength={2} maxLength={40} required /></label>
          <label>E-posta<input name="email" type="email" autoComplete="email" required /></label>
          <label>Şifre<input name="password" type="password" autoComplete="new-password" minLength={10} required /><small>En az 10 karakter; bir harf ve bir rakam.</small></label>
          <label>Şifre tekrarı<input name="password_confirmation" type="password" autoComplete="new-password" minLength={10} required /></label>
          <label>Dağıtım kurulum sırrı<input name="bootstrap_token" type="password" autoComplete="off" minLength={32} required /></label>
          <label className="check-row"><input name="terms" type="checkbox" value="accepted" required /> <span><Link href="/terms">Kullanım koşullarını</Link> kabul ediyorum.</span></label>
          <button className="button button--primary button--large" type="submit">İlk yöneticiyi oluştur</button>
        </form>
      </> : <>
        <p>{hasAdmin ? "İlk yönetici kurulumu tamamlanmış. Yeni yöneticiler Studio içindeki davet akışıyla eklenir." : "Dağıtım kurulum sırrı yapılandırılmadığı için bu akış kapalı."}</p>
        <Link className="button button--primary" href="/login">Studio girişine dön</Link>
      </>}
    </section>
  </main></div>;
}
