import type { Metadata } from "next";
import Link from "next/link";
import { SiteFooter } from "../../components/SiteFooter";
import { SiteHeader } from "../../components/SiteHeader";

export const metadata: Metadata = {
  title: "Telif bildirimi gönder — Panelya",
  description: "Panelya'da incelenmesini istediğin bir içerik için telif bildirimi oluştur.",
  alternates: { canonical: "/copyright/report" },
};

export default async function CopyrightReportPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const query = await searchParams;
  return <div className="site-shell"><SiteHeader />
    <main id="main-content" className="info-main wrap">
      <header className="info-hero"><p className="section-kicker">Hak sahipliği</p><h1>Telif bildirimi gönder</h1><p>İncelenmesini istediğin Panelya içeriğini ve hak sahipliği dayanağını açıkla. Bu form hukuki danışmanlık veya otomatik içerik kaldırma kararı değildir.</p></header>
      {query.error && <p className="form-message form-message--error" role="alert">{query.error}</p>}
      <div className="contact-layout copyright-layout"><section className="contact-card"><h2>Bildirim bilgileri</h2>
        <form className="stack-form" action="/api/copyright-notices" method="post">
          <label>Ad veya unvan<input name="claimant_name" minLength={2} maxLength={100} autoComplete="name" required /></label>
          <label>E-posta<input name="claimant_email" type="email" maxLength={160} autoComplete="email" required /></label>
          <label>Başvuru sıfatı<select name="claimant_role" defaultValue="rights_holder"><option value="rights_holder">Hak sahibiyim</option><option value="authorized_representative">Yetkili temsilciyim</option></select></label>
          <label>Korunan eserin açıklaması<textarea name="work_description" minLength={20} maxLength={1500} rows={5} required /><small>Eseri ayırt etmeye yetecek kısa ve somut bilgi ver.</small></label>
          <label>Özgün eser veya yetki kaynağı bağlantısı <span className="optional-label">isteğe bağlı</span><input name="original_work_url" type="url" maxLength={1000} inputMode="url" placeholder="https://…" /></label>
          <label>İncelenecek Panelya URL’si<input name="content_url" type="url" maxLength={1000} inputMode="url" placeholder="http://localhost:3000/seri/bolum" required /></label>
          <label>Hak sahipliği ve ihlal açıklaması<textarea name="rights_explanation" minLength={20} maxLength={2000} rows={7} required /><small>Kimlik belgesi, parola veya özel nitelikli kişisel veri ekleme.</small></label>
          <label className="check-row"><input name="good_faith" type="checkbox" value="yes" required /><span>Bildirimin iyi niyetle ve bildiğim kadarıyla doğru bilgilerle yapıldığını onaylıyorum.</span></label>
          <label className="check-row"><input name="authorized" type="checkbox" value="yes" required /><span>Hak sahibi olduğumu veya hak sahibi adına bildirim yapmaya yetkili olduğumu onaylıyorum.</span></label>
          <label className="form-trap" aria-hidden="true">Web sitesi<input name="website" tabIndex={-1} autoComplete="off" /></label>
          <button className="button button--primary button--large" type="submit">Bildirimi kaydet</button>
        </form>
      </section><aside className="contact-aside"><h2>Göndermeden önce</h2><p>Her bildirim tek bir Panelya URL’si için açılır. Birden fazla içerik varsa her biri için ayrı kayıt oluştur.</p><p>Dosya yüklemesi istemiyoruz; gerekli kanıtı bağlantı ve açıklama ile sınırlandırıyoruz.</p><p>Gönderimden sonra 90 gün geçerli, gizli bir durum bağlantısı alacaksın. Bağlantıyı paylaşma.</p><Link href="/copyright">Süreç bilgisini oku →</Link><Link href="/privacy">Gizlilik politikasını oku →</Link></aside></div>
    </main><SiteFooter /></div>;
}
