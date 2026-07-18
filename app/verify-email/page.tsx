import Link from "next/link";
import { AuthPageControls } from "../components/AuthPageControls";
import { SiteHeader } from "../components/SiteHeader";
import { inspectAccountToken } from "../lib/account-tokens";

export const dynamic = "force-dynamic";
export const metadata = { title: "E-posta doğrulama | Panelya", referrer: "same-origin" as const };

export default async function VerifyEmailPage({ searchParams }: { searchParams: Promise<{ token?: string; error?: string }> }) {
  const query = await searchParams;
  const token = query.token ?? "";
  const record = await inspectAccountToken(token, "verify_email");
  return <div className="site-shell auth-shell"><SiteHeader compact /><main id="main-content" className="auth-main"><AuthPageControls closeHref="/account" />
    <section className="auth-card"><p className="section-kicker">E-posta doğrulama</p><h1>Adresini onayla</h1>
      {query.error && <p className="form-message form-message--error" role="alert">{query.error}</p>}
      {record ? <><p><strong>{record.target_email}</strong> adresini bu Panelya hesabına bağlamayı onayla.</p><form action="/api/auth/email-verification/complete" method="post"><input type="hidden" name="token" value={token} /><button className="button button--primary button--large" type="submit">E-postayı doğrula</button></form></> : <><p>Bağlantı geçersiz, kullanılmış veya süresi dolmuş.</p><Link className="button button--ghost" href="/account">Hesaba dön</Link></>}
    </section></main></div>;
}
