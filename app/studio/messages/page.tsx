import Link from "next/link";
import { redirect } from "next/navigation";
import { SiteHeader } from "../../components/SiteHeader";
import { getCurrentUser } from "../../lib/auth";
import { listCopyrightNotices, type CopyrightNoticeStatus } from "../../lib/copyright-notices";
import { getDatabase } from "../../lib/database";
import { publicSiteUrlForCurrentRequest } from "../../lib/server-site-origins";

export const dynamic = "force-dynamic";

type MessageRow = {
  id: string;
  name: string;
  email: string;
  subject: string;
  message: string;
  status: "new" | "handled";
  created_at: number;
};

const subjectLabels: Record<string, string> = { general: "Genel", creator: "Üretici", technical: "Teknik" };
const copyrightStatusLabels: Record<CopyrightNoticeStatus, string> = {
  submitted: "Alındı",
  under_review: "İnceleniyor",
  needs_information: "Ek bilgi bekleniyor",
  action_taken: "İşlem tamamlandı",
  rejected: "Uygun bulunmadı",
};

export default async function StudioMessagesPage({ searchParams }: { searchParams: Promise<{ copyright_updated?: string; copyright_error?: string }> }) {
  const user = await getCurrentUser();
  if (!user) redirect("/login?return_to=/messages");
  if (user.role !== "admin") redirect("/account?error=Studio%20yalnızca%20yönetici%20hesaplarına%20açık.");
  const query = await searchParams;
  const db = await getDatabase();
  const [publicHome, publicReportUrl, notices, rows] = await Promise.all([
    publicSiteUrlForCurrentRequest("/"),
    publicSiteUrlForCurrentRequest("/copyright/report"),
    listCopyrightNotices(),
    db.prepare("SELECT id, name, email, subject, message, status, created_at FROM contact_messages ORDER BY status ASC, created_at DESC").all<MessageRow>(),
  ]);
  const formatter = new Intl.DateTimeFormat("tr-TR", { dateStyle: "medium", timeStyle: "short", timeZone: "Europe/Istanbul" });

  return <div className="site-shell studio-shell"><SiteHeader compact homeHref={publicHome} /><main id="main-content" className="studio-main wrap">
    <div className="studio-top"><div><p className="section-kicker">Operasyon</p><h1>Mesaj ve hak talepleri</h1><p>Genel iletişim mesajlarını ve kayıtlı telif bildirimlerini aynı operasyon alanından yönet.</p></div><Link className="button button--ghost" href="/">← Studio</Link></div>

    <section className="studio-section" id="copyright-notices" aria-labelledby="copyright-notices-title">
      <div className="section-heading"><div><p className="section-kicker">Hak talepleri</p><h2 id="copyright-notices-title">Telif bildirimleri</h2><p>Başvuru sahibi yalnız gizli durum bağlantısındaki durum ve public yanıt alanını görür.</p></div><span className="sort-note">{notices.length} kayıt</span></div>
      {query.copyright_updated && <p className="form-message form-message--success" role="status">Telif bildirimi güncellendi.</p>}
      {query.copyright_error && <p className="form-message form-message--error" role="alert">{query.copyright_error}</p>}
      <div className="copyright-admin-list">{notices.length ? notices.map((notice) => <article className="copyright-admin-card" key={notice.id}>
        <header><div><span className="pill pill--accent">{copyrightStatusLabels[notice.status]}</span><strong>{notice.referenceCode}</strong><span>{notice.claimantName} · {notice.claimantRole === "rights_holder" ? "Hak sahibi" : "Yetkili temsilci"}</span><a href={`mailto:${notice.claimantEmail}`}>{notice.claimantEmail}</a></div><time dateTime={new Date(notice.createdAt).toISOString()}>{formatter.format(notice.createdAt)}</time></header>
        <dl><div><dt>Korunan eser</dt><dd>{notice.workDescription}</dd></div><div><dt>İncelenecek içerik</dt><dd><a href={notice.contentUrl} target="_blank" rel="noreferrer">{notice.contentUrl}</a></dd></div>{notice.originalWorkUrl && <div><dt>Özgün eser / yetki kaynağı</dt><dd><a href={notice.originalWorkUrl} target="_blank" rel="noreferrer">{notice.originalWorkUrl}</a></dd></div>}<div><dt>Hak açıklaması</dt><dd>{notice.rightsExplanation}</dd></div></dl>
        <form className="stack-form copyright-admin-form" action={`/api/admin/copyright-notices/${notice.id}`} method="post">
          <label>Durum<select name="status" defaultValue={notice.status}>{Object.entries(copyrightStatusLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label>
          <label>Başvuru sahibine gösterilecek yanıt<textarea name="public_response" maxLength={1200} rows={4} defaultValue={notice.publicResponse ?? ""} /><small>Serbest iç not, parola, token veya başka bir başvurunun kişisel verisini yazma.</small></label>
          <button className="button button--primary" type="submit">Durumu güncelle</button>
        </form>
      </article>) : <div className="empty-state"><strong>Henüz telif bildirimi yok.</strong><p>Public telif formundan gönderilen kayıtlar burada görünecek.</p><a className="button button--primary" href={publicReportUrl}>Test bildirimi gönder</a></div>}</div>
    </section>

    <section className="studio-section" aria-labelledby="contact-messages-title"><div className="section-heading"><div><p className="section-kicker">Genel iletişim</p><h2 id="contact-messages-title">Mesaj kutusu</h2></div><span className="sort-note">{rows.results.length} kayıt</span></div>
      <div className="message-list" aria-label="İletişim mesajları">{rows.results.length ? rows.results.map((item) => <article key={item.id} className={`message-card${item.status === "handled" ? " is-handled" : ""}`}><header><div><span className="pill pill--accent">{subjectLabels[item.subject] ?? item.subject}</span><strong>{item.name}</strong><a href={`mailto:${item.email}`}>{item.email}</a></div><time dateTime={new Date(item.created_at).toISOString()}>{formatter.format(item.created_at)}</time></header><p>{item.message}</p><form action={`/api/admin/messages/${item.id}`} method="post"><input type="hidden" name="action" value={item.status === "new" ? "handle" : "reopen"} /><button className="button button--ghost" type="submit">{item.status === "new" ? "İşlendi olarak işaretle" : "Yeniden aç"}</button></form></article>) : <div className="empty-state"><strong>Mesaj kutusu boş.</strong><p>İletişim formundan gönderilen mesajlar burada görünecek.</p><a className="button button--primary" href={new URL("/contact", publicHome).toString()}>Test mesajı gönder</a></div>}</div>
    </section>
  </main></div>;
}
