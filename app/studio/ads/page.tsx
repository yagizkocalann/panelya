import Link from "next/link";
import { redirect } from "next/navigation";
import { AdTestSlot } from "../../components/AdTestSlot";
import { SiteHeader } from "../../components/SiteHeader";
import { getCurrentUser } from "../../lib/auth";
import { publicSiteUrlForCurrentRequest } from "../../lib/server-site-origins";

export const dynamic = "force-dynamic";

export default async function StudioAdsPage() {
  const user = await getCurrentUser();
  if (!user) redirect("/login?return_to=/ads");
  if (user.role !== "admin") redirect("/account?error=Studio%20yalnızca%20yönetici%20hesaplarına%20açık.");
  const publicHome = await publicSiteUrlForCurrentRequest("/");

  return <div className="site-shell studio-shell"><SiteHeader compact homeHref={publicHome} />
    <main id="main-content" className="studio-main wrap">
      <div className="studio-top"><div><p className="section-kicker">Gelir · test ortamı</p><h1>Reklam Laboratuvarı</h1><p>Google’ın resmî örnek ağıyla reklam yüklenmesini, ayrılan alanı ve reklam engelleyici davranışını localhost üzerinde doğrula.</p></div><Link className="button button--ghost" href="/">← Studio</Link></div>
      <aside className="studio-notice"><strong>Güvenli test:</strong> Bu sayfa Panelya’ya ait publisher kimliği kullanmaz. Test kreatifine otomatik tıklama yapılmaz ve gelir oluşmaz.</aside>
      <section className="ad-lab-grid" aria-labelledby="ad-lab-title">
        <div><p className="section-kicker">Canlı bağlantı</p><h2 id="ad-lab-title">Google 300 × 250 test birimi</h2><p>Yeşil durum etiketi görünürse Google testi başarıyla render edilmiştir. Reklam engelleyici açıksa açıklayıcı hata durumu gösterilir.</p><AdTestSlot placement="studio-lab-01" /></div>
        <aside className="ad-lab-checklist"><h2>Test kontrol listesi</h2><ol><li>Google test kreatifi alanın içinde görünür.</li><li>Sayfa yüklenirken alan yüksekliği değişmez.</li><li>390 px mobil görünümde yatay taşma oluşmaz.</li><li>Reklam engelleyicide sayfa akışı bozulmaz.</li><li>Okuyucu kontrollerine yakın yanlış tıklama alanı oluşmaz.</li></ol></aside>
      </section>
      <section className="studio-section"><div className="section-heading"><div><p className="section-kicker">Aktif yerleşimler</p><h2>Web reklam haritası</h2></div><span className="sort-note">Test ağı</span></div><div className="studio-table" role="table"><div role="row" className="studio-table__head"><span>Yerleşim</span><span>Sayfa</span><span>Boyut</span><span>Durum</span></div><div role="row"><span><strong>home-feed-01</strong><small>İçerik akışı arası</small></span><span>Ana sayfa</span><span>300 × 250</span><strong className="status-live">Aktif test</strong></div><div role="row"><span><strong>series-detail-01</strong><small>Detay ve bölüm listesi arası</small></span><span>Seri sayfası</span><span>300 × 250</span><strong className="status-live">Aktif test</strong></div></div></section>
    </main>
  </div>;
}
