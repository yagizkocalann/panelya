import Link from "next/link";
import { redirect } from "next/navigation";
import { SiteHeader } from "../../../components/SiteHeader";
import { getCurrentUser } from "../../../lib/auth";
import { publicSiteUrlForCurrentRequest } from "../../../lib/server-site-origins";
import { SeriesForm } from "../ContentForms";

export const dynamic = "force-dynamic";

export default async function NewSeriesPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const user = await getCurrentUser();
  if (!user) redirect("/login?return_to=/content/new");
  if (user.role !== "admin") redirect("/account?error=Studio%20yalnızca%20yönetici%20hesaplarına%20açık.");
  const [publicHome, query] = await Promise.all([publicSiteUrlForCurrentRequest("/"), searchParams]);
  return <div className="site-shell studio-shell"><SiteHeader compact homeHref={publicHome} /><main id="main-content" className="studio-main wrap">
    <div className="studio-top"><div><p className="section-kicker">İçerik · yeni seri</p><h1>Taslak seri oluştur</h1><p>Seri kimliğini, katalog metinlerini ve yayın ayarlarını hazırla.</p></div><Link className="button button--ghost" href="/content">← İçerik</Link></div>
    {query.error && <p className="form-message form-message--error" role="alert">{query.error}</p>}
    <SeriesForm />
  </main></div>;
}
