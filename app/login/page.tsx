import Link from "next/link";
import { redirect } from "next/navigation";
import { SiteHeader } from "../components/SiteHeader";
import { AuthPageControls } from "../components/AuthPageControls";
import { getCurrentUser, safeAuthClosePath, safeReturnTo } from "../lib/auth";

export const dynamic = "force-dynamic";

export default async function LoginPage({ searchParams }: { searchParams: Promise<{ error?: string; notice?: string; return_to?: string }> }) {
  const user = await getCurrentUser();
  const query = await searchParams;
  const returnTo = safeReturnTo(query.return_to, "/account");
  const closeHref = safeAuthClosePath(query.return_to);
  if (user) redirect(returnTo);
  return (
    <div className="site-shell auth-shell"><SiteHeader compact />
      <main id="main-content" className="auth-main"><AuthPageControls closeHref={closeHref} />
        <section className="auth-card"><p className="section-kicker">Tekrar hoş geldin</p><h1>Giriş yap</h1><p>Okuma listen ve favorilerin seni bekliyor.</p>
          {query.error && <p className="form-message form-message--error" role="alert">{query.error}</p>}
          {query.notice && <p className="form-message form-message--success" role="status">{query.notice}</p>}
          <form className="stack-form" action="/api/auth/login" method="post">
            <input type="hidden" name="return_to" value={returnTo} />
            <label>E-posta<input name="email" type="email" autoComplete="email" required /></label>
            <label>Şifre<input name="password" type="password" autoComplete="current-password" required /></label>
            <Link className="form-inline-link" href="/forgot-password">Şifremi unuttum</Link>
            <label className="check-row"><input name="remember" type="checkbox" value="yes" /> Bu cihazda oturumu açık tut</label>
            <button className="button button--primary button--large" type="submit">Giriş yap</button>
          </form>
          <p className="auth-switch">Hesabın yok mu? <Link href={`/register?return_to=${encodeURIComponent(returnTo)}`}>Üye ol</Link></p>
        </section>
      </main>
    </div>
  );
}
