import { redirect } from "next/navigation";
import { AuthPageControls } from "../components/AuthPageControls";
import { SiteHeader } from "../components/SiteHeader";
import { getCurrentUser, safeAuthClosePath, safeReturnTo } from "../lib/auth";

export const dynamic = "force-dynamic";

export default async function ReauthenticatePage({ searchParams }: { searchParams: Promise<{ error?: string; return_to?: string }> }) {
  const query = await searchParams;
  const returnTo = safeReturnTo(query.return_to, "/account");
  const user = await getCurrentUser();
  if (!user) redirect(`/login?return_to=${encodeURIComponent(returnTo)}&notice=${encodeURIComponent("Oturumun sona erdi; devam etmek için yeniden giriş yap.")}`);

  return <div className="site-shell auth-shell"><SiteHeader compact />
    <main id="main-content" className="auth-main"><AuthPageControls closeHref={safeAuthClosePath(returnTo)} />
      <section className="auth-card"><p className="section-kicker">Güvenlik kontrolü</p><h1>Şifreni yeniden doğrula</h1>
        <p><strong>{user.email}</strong> hesabıyla hassas işleme devam etmek için mevcut şifreni gir. Doğrulama yalnızca bu tarayıcı oturumunda 10 dakika geçerlidir.</p>
        {query.error && <p className="form-message form-message--error" role="alert">{query.error}</p>}
        <form className="stack-form" action="/api/auth/reauthenticate" method="post">
          <input type="hidden" name="return_to" value={returnTo} />
          <label>Mevcut şifre<input name="password" type="password" autoComplete="current-password" required autoFocus /></label>
          <button className="button button--primary button--large" type="submit">Doğrula ve devam et</button>
        </form>
      </section>
    </main>
  </div>;
}
