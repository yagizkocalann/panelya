import Link from "next/link";
import { redirect } from "next/navigation";
import { SiteHeader } from "../../components/SiteHeader";
import { getCurrentUser } from "../../lib/auth";
import { publicSiteUrlForCurrentRequest } from "../../lib/server-site-origins";

export const dynamic = "force-dynamic";

const priorityChecks = [
  { id: "QA-ADM-01", title: "Yönetici davetini kabul etme", path: "/users → /outbox", result: "Yeni test yöneticisi oluşmalı, Studio oturumu açılmalı ve davet kabul edildi görünmeli." },
  { id: "QA-STU-06", title: "Outbox saklama ve temizleme", path: "/outbox", result: "Yalnız süresi dolan sentetik kayıtlar temizlenmeli; aktif bağlantılar kalmalı ve audit yazılmalı." },
  { id: "QA-RESP-01", title: "Responsive genel tur", path: "Public + Studio", result: "1440, 1024, 768, 390 ve 360 px'te taşma, kırpılma veya 44 px altı dokunma hedefi olmamalı." },
] as const;

export default async function StudioQaPage() {
  const user = await getCurrentUser();
  if (!user) redirect("/login?return_to=/qa");
  if (user.role !== "admin") redirect("/account?error=Studio%20yalnızca%20yönetici%20hesaplarına%20açık.");
  const publicHome = await publicSiteUrlForCurrentRequest("/");

  return <div className="site-shell studio-shell"><SiteHeader compact homeHref={publicHome} /><main id="main-content" className="studio-main wrap">
    <div className="studio-top"><div><p className="section-kicker">Kalıcı hatırlatma</p><h1>Manuel QA kuyruğu</h1><p>Otomatik testten geçse bile senin daha sonra elle görmen gereken feature’lar burada hatırlatılır.</p></div><Link className="button button--ghost" href="/">← Studio</Link></div>
    <aside className="studio-notice"><strong>Tek kayıt kaynağı:</strong> Ayrıntılı senaryolar repodaki <code>docs/manual-qa-checklist.md</code> dosyasında tutulur. Yeni feature bu listeye eklenmeden tamamlanmış sayılmaz.</aside>
    <section className="studio-section" aria-labelledby="qa-priority-title"><div className="section-heading"><div><p className="section-kicker">Kullanıcı testi bekliyor</p><h2 id="qa-priority-title">Öncelikli kontroller</h2></div><span className="sort-note">{priorityChecks.length} hatırlatma</span></div>
      <div className="message-list">{priorityChecks.map((check) => <article className="message-card" key={check.id}><header><div><span className="pill pill--accent">BEKLİYOR</span><strong>{check.id} · {check.title}</strong><span>{check.path}</span></div></header><p>{check.result}</p></article>)}</div>
    </section>
  </main></div>;
}
