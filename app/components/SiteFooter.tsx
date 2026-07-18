import Link from "next/link";

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <div className="footer-inner">
        <div>
          <Link className="brand brand--footer" href="/"><span className="brand-mark" aria-hidden="true"><i /><i /><i /></span><span>panelya</span></Link>
          <p>Yeni nesil Türkçe dikey hikâyeler. Okumak için kaydır, keşfetmek için kal.</p>
        </div>
        <div className="footer-links">
          <div><strong>Panelya</strong><Link href="/">Keşfet</Link><Link href="/#new-series">Yeni seriler</Link><Link href="/creators">İçerik üreticileri</Link></div>
          <div><strong>Bilgi</strong><Link href="/about">Hakkımızda</Link><Link href="/publishing-principles">Yayın ilkeleri</Link><Link href="/contact">İletişim</Link></div>
          <div><strong>Yasal</strong><Link href="/privacy">Gizlilik</Link><Link href="/terms">Kullanım koşulları</Link><Link href="/copyright">Telif bildirimi</Link></div>
        </div>
      </div>
      <div className="footer-bottom"><span>© 2026 Panelya</span><span>Özgün hikâyeler için üretildi.</span></div>
    </footer>
  );
}
