import Link from "next/link";
import { listPublishedGenres } from "../lib/content-repository";
import { ConsentSettingsButton } from "./ConsentSettingsButton";

export async function SiteFooter() {
  const genres = await listPublishedGenres();
  const featuredGenres = genres.slice(0, 12);

  return (
    <footer className="site-footer">
      <div className="footer-inner">
        <div className="footer-brand">
          <Link className="brand brand--footer" href="/"><span className="brand-mark" aria-hidden="true"><i /><i /><i /></span><span>panelya</span></Link>
          <p>Türkçe ve mobil öncelikli dikey çizgi hikâyeleri ücretsiz keşfet, kütüphanene ekle ve kaldığın yerden okumaya devam et.</p>
          <Link className="footer-catalog-link" href="/?view=catalog">Tüm serileri keşfet <span aria-hidden="true">→</span></Link>
        </div>
        <nav className="footer-links" aria-label="Alt bilgi bağlantıları">
          <div className="footer-link-group footer-link-group--genres">
            <strong>Kategoriler</strong>
            <div className="footer-category-grid">
              {featuredGenres.map((genre) => <Link key={genre} href={`/?genre=${encodeURIComponent(genre)}`}>{genre}</Link>)}
            </div>
            <Link className="footer-all-link" href="/?view=catalog">Tüm türler</Link>
          </div>
          <div className="footer-link-group"><strong>Bilgi</strong><Link href="/about">Hakkımızda</Link><Link href="/creators">İçerik üreticileri</Link><Link href="/publishing-principles">Yayın ilkeleri</Link><Link href="/production-journal">Üretim günlüğü</Link><Link href="/contact">İletişim</Link></div>
          <div className="footer-link-group"><strong>Hesap</strong><Link href="/login">Giriş yap</Link><Link href="/register">Üye ol</Link><Link href="/library">Kütüphanem</Link><Link href="/account">Hesabım</Link></div>
          <div className="footer-link-group"><strong>Yasal</strong><Link href="/privacy">Gizlilik</Link><Link href="/terms">Kullanım koşulları</Link><Link href="/copyright">Telif bildirimi</Link><ConsentSettingsButton /></div>
        </nav>
      </div>
      <div className="footer-bottom"><span>© 2026 Panelya</span><span>Özgün hikâyeler için üretildi.</span></div>
    </footer>
  );
}
