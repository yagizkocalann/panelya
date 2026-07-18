import Link from "next/link";
import { redirect } from "next/navigation";
import { SiteHeader } from "../components/SiteHeader";
import { AuthPageControls } from "../components/AuthPageControls";
import { getCurrentUser, safeAuthClosePath, safeReturnTo } from "../lib/auth";

export const dynamic = "force-dynamic";

export default async function RegisterPage({ searchParams }: { searchParams: Promise<{ error?: string; return_to?: string }> }) {
  const user = await getCurrentUser();
  const query = await searchParams;
  const returnTo = safeReturnTo(query.return_to, "/account");
  const closeHref = safeAuthClosePath(query.return_to);
  if (user) redirect(returnTo);
  return (
    <div className="site-shell auth-shell"><SiteHeader compact />
      <main id="main-content" className="auth-main"><AuthPageControls closeHref={closeHref} />
        <section className="auth-card"><p className="section-kicker">Ücretsiz yerel hesap</p><h1>Panelya&apos;ya katıl</h1><p>Bu geliştirme sürümündeki hesap yalnızca bu bilgisayardaki yerel veritabanında tutulur.</p>
          {query.error && <p className="form-message form-message--error" role="alert">{query.error}</p>}
          <form className="stack-form" action="/api/auth/register" method="post">
            <input type="hidden" name="return_to" value={returnTo} />
            <label>Görünen ad<input name="display_name" autoComplete="name" minLength={2} maxLength={40} required /></label>
            <label>E-posta<input name="email" type="email" autoComplete="email" required /></label>
            <label>Şifre<input name="password" type="password" autoComplete="new-password" minLength={10} required /><small>En az 10 karakter; bir harf ve bir rakam.</small></label>
            <label>Şifre tekrarı<input name="password_confirmation" type="password" autoComplete="new-password" minLength={10} required /></label>
            <label className="check-row"><input name="terms" type="checkbox" value="accepted" required /> Yerel test kullanım koşullarını kabul ediyorum.</label>
            <button className="button button--primary button--large" type="submit">Hesap oluştur</button>
          </form>
          <p className="auth-switch">Zaten hesabın var mı? <Link href={`/login?return_to=${encodeURIComponent(returnTo)}`}>Giriş yap</Link></p>
        </section>
      </main>
    </div>
  );
}
