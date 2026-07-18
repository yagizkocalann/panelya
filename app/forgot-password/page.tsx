import Link from "next/link";
import { AuthPageControls } from "../components/AuthPageControls";
import { SiteHeader } from "../components/SiteHeader";

export const metadata = { title: "Şifremi unuttum | Panelya" };

export default async function ForgotPasswordPage({ searchParams }: { searchParams: Promise<{ sent?: string }> }) {
  const query = await searchParams;
  return <div className="site-shell auth-shell"><SiteHeader compact /><main id="main-content" className="auth-main"><AuthPageControls closeHref="/" />
    <section className="auth-card"><p className="section-kicker">Hesap kurtarma</p><h1>Şifreni yenile</h1><p>E-posta adresini gir. Hesap varsa yerel e-posta kutusuna 30 dakikalık bağlantı bırakacağız.</p>
      {query.sent && <p className="form-message form-message--success" role="status">Adres kayıtlı olsun ya da olmasın, işlem tamamlandı. Yerel testte bağlantıyı Studio e-posta kutusunda görebilirsin.</p>}
      <form className="stack-form" action="/api/auth/password-reset/request" method="post"><label>E-posta<input name="email" type="email" autoComplete="email" required /></label><button className="button button--primary button--large" type="submit">Sıfırlama bağlantısı iste</button></form>
      <p className="auth-switch"><Link href="/login">Giriş ekranına dön</Link></p>
    </section></main></div>;
}
