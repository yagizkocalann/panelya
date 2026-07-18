import Link from "next/link";
import { AuthPageControls } from "../components/AuthPageControls";
import { SiteHeader } from "../components/SiteHeader";
import { inspectAccountToken } from "../lib/account-tokens";

export const dynamic = "force-dynamic";
export const metadata = { title: "Yeni şifre | Panelya", referrer: "same-origin" as const };

export default async function ResetPasswordPage({ searchParams }: { searchParams: Promise<{ token?: string; error?: string }> }) {
  const query = await searchParams;
  const token = query.token ?? "";
  const valid = Boolean(await inspectAccountToken(token, "password_reset"));
  return <div className="site-shell auth-shell"><SiteHeader compact /><main id="main-content" className="auth-main"><AuthPageControls closeHref="/login" />
    <section className="auth-card"><p className="section-kicker">Hesap kurtarma</p><h1>Yeni şifre belirle</h1>
      {query.error && <p className="form-message form-message--error" role="alert">{query.error}</p>}
      {valid ? <form className="stack-form" action="/api/auth/password-reset/complete" method="post"><input type="hidden" name="token" value={token} /><label>Yeni şifre<input name="password" type="password" autoComplete="new-password" minLength={10} required /><small>En az 10 karakter; bir harf ve bir rakam.</small></label><label>Yeni şifre tekrarı<input name="password_confirmation" type="password" autoComplete="new-password" minLength={10} required /></label><button className="button button--primary button--large" type="submit">Şifreyi yenile</button></form> : <><p>Bağlantı geçersiz, kullanılmış veya süresi dolmuş.</p><Link className="button button--primary" href="/forgot-password">Yeni bağlantı iste</Link></>}
    </section></main></div>;
}
