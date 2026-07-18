import Link from "next/link";
import { redirect } from "next/navigation";
import { SiteHeader } from "../../components/SiteHeader";
import { getCurrentUser } from "../../lib/auth";
import { getDatabase } from "../../lib/database";
import { publicSiteUrlForCurrentRequest } from "../../lib/server-site-origins";

export const dynamic = "force-dynamic";
type MessageRow = { id: string; name: string; email: string; subject: string; message: string; status: "new" | "handled"; created_at: number };
const subjectLabels: Record<string, string> = { general: "Genel", creator: "Üretici", copyright: "Telif", technical: "Teknik" };

export default async function StudioMessagesPage() {
  const user = await getCurrentUser();
  if (!user) redirect("/login?return_to=/messages");
  if (user.role !== "admin") redirect("/account?error=Studio%20yalnızca%20yönetici%20hesaplarına%20açık.");
  const publicHome = await publicSiteUrlForCurrentRequest("/");
  const db = await getDatabase();
  const rows = await db.prepare("SELECT id, name, email, subject, message, status, created_at FROM contact_messages ORDER BY status ASC, created_at DESC").all<MessageRow>();
  return <div className="site-shell studio-shell"><SiteHeader compact homeHref={publicHome} /><main id="main-content" className="studio-main wrap">
    <div className="studio-top"><div><p className="section-kicker">Operasyon</p><h1>Mesaj kutusu</h1><p>İletişim, üretici ve telif başvurularını lokal ortamda incele ve durumunu güncelle.</p></div><Link className="button button--ghost" href="/">← Studio</Link></div>
    <section className="message-list" aria-label="İletişim mesajları">{rows.results.length ? rows.results.map((item) => <article key={item.id} className={`message-card${item.status === "handled" ? " is-handled" : ""}`}><header><div><span className="pill pill--accent">{subjectLabels[item.subject] ?? item.subject}</span><strong>{item.name}</strong><a href={`mailto:${item.email}`}>{item.email}</a></div><time dateTime={new Date(item.created_at).toISOString()}>{new Intl.DateTimeFormat("tr-TR", { dateStyle: "medium", timeStyle: "short" }).format(new Date(item.created_at))}</time></header><p>{item.message}</p><form action={`/api/admin/messages/${item.id}`} method="post"><input type="hidden" name="action" value={item.status === "new" ? "handle" : "reopen"} /><button className="button button--ghost" type="submit">{item.status === "new" ? "İşlendi olarak işaretle" : "Yeniden aç"}</button></form></article>) : <div className="empty-state"><strong>Mesaj kutusu boş.</strong><p>İletişim formundan gönderilen mesajlar burada görünecek.</p><Link className="button button--primary" href="/contact">Test mesajı gönder</Link></div>}</section>
  </main></div>;
}
