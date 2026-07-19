import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { SiteFooter } from "../../../components/SiteFooter";
import { SiteHeader } from "../../../components/SiteHeader";
import { getCopyrightNoticeByAccessToken } from "../../../lib/copyright-notices";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Telif bildirimi durumu — Panelya", robots: { index: false, follow: false } };

const statusLabels = {
  submitted: "Alındı",
  under_review: "İnceleniyor",
  needs_information: "Ek bilgi bekleniyor",
  action_taken: "İşlem tamamlandı",
  rejected: "Talep uygun bulunmadı",
} as const;

export default async function CopyrightStatusPage({ params, searchParams }: { params: Promise<{ token: string }>; searchParams: Promise<{ submitted?: string }> }) {
  const [{ token }, query] = await Promise.all([params, searchParams]);
  const notice = await getCopyrightNoticeByAccessToken(token);
  if (!notice) notFound();
  const formatter = new Intl.DateTimeFormat("tr-TR", { dateStyle: "long", timeStyle: "short", timeZone: "Europe/Istanbul" });
  return <div className="site-shell"><SiteHeader />
    <main id="main-content" className="info-main wrap"><header className="info-hero"><p className="section-kicker">Gizli durum bağlantısı</p><h1>Telif bildirimi durumu</h1><p>Bu sayfa yalnız bağlantıya sahip kişi tarafından görüntülenebilir. Bağlantıyı paylaşma veya herkese açık bir yere yapıştırma.</p></header>
      {query.submitted && <p className="form-message form-message--success" role="status">Bildirimin kaydedildi. Bu durum bağlantısını güvenli bir yere kaydet.</p>}
      <section className="copyright-status-card" aria-labelledby="notice-status-title"><div><span className="pill pill--accent">{statusLabels[notice.status]}</span><h2 id="notice-status-title">{notice.referenceCode}</h2><p>İncelenen içerik: <a href={notice.contentUrl} rel="noreferrer">{notice.contentUrl}</a></p></div>
        <dl><div><dt>Gönderim</dt><dd>{formatter.format(notice.createdAt)}</dd></div><div><dt>Son güncelleme</dt><dd>{formatter.format(notice.updatedAt)}</dd></div><div><dt>Durum bağlantısı bitişi</dt><dd>{formatter.format(notice.accessExpiresAt)}</dd></div></dl>
        {notice.publicResponse ? <div className="copyright-response"><strong>Panelya yanıtı</strong><p>{notice.publicResponse}</p></div> : <p className="copyright-status-note">Henüz paylaşılmış bir değerlendirme notu yok. Durum değiştiğinde bu bağlantıda görünecek.</p>}
        <div className="info-actions"><Link className="button button--ghost" href="/copyright">Süreç bilgisine dön</Link><Link className="button button--ghost" href="/contact">İletişime geç</Link></div>
      </section>
    </main><SiteFooter /></div>;
}
