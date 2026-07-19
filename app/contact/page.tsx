import type { Metadata } from "next";
import Link from "next/link";
import { SiteFooter } from "../components/SiteFooter";
import { SiteHeader } from "../components/SiteHeader";

export const metadata: Metadata = { title: "İletişim — Panelya", description: "Panelya'ya genel, teknik veya üretici mesajı gönder.", alternates: { canonical: "/contact" } };
const subjectValues = new Set(["general", "creator", "technical"]);

export default async function ContactPage({ searchParams }: { searchParams: Promise<{ subject?: string; sent?: string; error?: string }> }) {
  const query = await searchParams;
  const subject = subjectValues.has(query.subject ?? "") ? query.subject : "general";
  return <div className="site-shell"><SiteHeader />
    <main id="main-content" className="info-main wrap"><header className="info-hero"><p className="section-kicker">Bize ulaş</p><h1>İletişim</h1><p>Mesajın lokal D1 veritabanına kaydedilir ve yalnızca Studio yöneticisinin mesaj kutusunda görünür.</p></header>
      {query.sent && <p className="form-message form-message--success" role="status">Mesajın kaydedildi. Studio mesaj kutusuna ulaştı.</p>}
      {query.error && <p className="form-message form-message--error" role="alert">{query.error}</p>}
      <div className="contact-layout"><section className="contact-card"><h2>Mesaj gönder</h2><form className="stack-form" action="/api/contact" method="post">
        <label>Adın<input name="name" minLength={2} maxLength={80} autoComplete="name" required /></label>
        <label>E-posta<input name="email" type="email" maxLength={160} autoComplete="email" required /></label>
        <label>Konu<select name="subject" defaultValue={subject}><option value="general">Genel</option><option value="creator">İçerik üreticisi başvurusu</option><option value="technical">Teknik sorun</option></select></label>
        <label>Mesaj<textarea name="message" minLength={20} maxLength={3000} rows={8} required /></label>
        <button className="button button--primary button--large" type="submit">Mesajı gönder</button>
      </form></section><aside className="contact-aside"><h2>Doğru kanal</h2><p>İçerik projesi gönderiyorsan üretici sürecini, hak bildirimi yapıyorsan kayıtlı telif formunu kullan.</p><Link href="/creators">İçerik üreticileri →</Link><Link href="/copyright/report">Telif bildirimi →</Link><Link href="/publishing-principles">Yayın ilkeleri →</Link></aside></div>
    </main><SiteFooter /></div>;
}
