import Link from "next/link";
import { redirect } from "next/navigation";
import { SiteHeader } from "../components/SiteHeader";
import { getCurrentUser } from "../lib/auth";
import { getContentCounts, listStudioSeries } from "../lib/content-repository";
import { getDatabase } from "../lib/database";
import { publicSiteUrlForCurrentRequest } from "../lib/server-site-origins";

export const dynamic = "force-dynamic";

export default async function StudioPage() {
  const user = await getCurrentUser();
  if (!user) redirect("/login?return_to=/");
  if (user.role !== "admin") redirect("/account?error=Studio%20yalnızca%20yönetici%20hesaplarına%20açık.");
  const publicHome = await publicSiteUrlForCurrentRequest("/");
  const db = await getDatabase();
  const [users, saved, progress, openReports, contentCounts, seriesCatalog] = await Promise.all([
    db.prepare("SELECT COUNT(*) AS count FROM users").first<{ count: number }>(),
    db.prepare("SELECT COUNT(*) AS count FROM library_items").first<{ count: number }>(),
    db.prepare("SELECT COUNT(*) AS count FROM reading_progress").first<{ count: number }>(),
    db.prepare("SELECT COUNT(*) AS count FROM review_reports WHERE status = 'open'").first<{ count: number }>(),
    getContentCounts(),
    listStudioSeries(),
  ]);
  return <div className="site-shell studio-shell"><SiteHeader compact homeHref={publicHome} />
    <main id="main-content" className="studio-main wrap">
      <div className="studio-top"><div><p className="section-kicker">Ayrı yönetim alanı</p><h1>Panelya Studio</h1><p>İçerik, bölüm ve platform operasyonları public siteden ayrılmış Studio hostunda yönetilir.</p></div><Link className="button button--ghost" href={publicHome}>Siteyi görüntüle</Link></div>
      <aside className="studio-notice"><strong>Yetki sınırı:</strong> İlk hesap yalnız localhost QA ortamında yönetici olabilir. Production public kaydı her zaman okuyucudur; yöneticiler bootstrap ve davet akışıyla eklenir.</aside>
      <nav className="studio-module-grid" aria-label="Studio modülleri">
        <article><span>İçerik</span><strong>Seri ve bölümler</strong><small>Mevcut katalog ve bölüm envanteri</small><Link className="button button--ghost" href="/content">Envanteri aç</Link></article>
        <article><span>Medya</span><strong>Kapak ve paneller</strong><small>Doğrulanan R2 görselleri ve içerik bağlantıları</small><Link className="button button--ghost" href="/media">Medyayı aç</Link></article>
        <article className="is-active"><span>Gelir</span><strong>Reklam Laboratuvarı</strong><small>Google GPT test ağı bağlı</small><Link className="button button--primary" href="/ads">Testleri aç</Link></article>
        <article><span>Operasyon</span><strong>Mesaj ve hak talepleri</strong><small>İletişim mesajları ile izlenebilir telif bildirimleri</small><Link className="button button--ghost" href="/messages">Talepleri aç</Link></article>
        <article><span>Kimlik servisi</span><strong>Yerel e-posta kutusu</strong><small>Doğrulama ve şifre sıfırlama bildirimleri</small><Link className="button button--ghost" href="/outbox">E-postaları aç</Link></article>
        <article><span>Topluluk</span><strong>Moderasyon</strong><small>Puan, yorum ve okuyucu raporları</small><Link className="button button--ghost" href="/moderation">Kuyruğu aç</Link></article>
        <article><span>Erişim</span><strong>Kullanıcılar ve roller</strong><small>Hesap rolleri, doğrulama ve oturum özeti</small><Link className="button button--ghost" href="/users">Kullanıcıları aç</Link></article>
        <article><span>Güvenlik</span><strong>Audit günlüğü</strong><small>Hesap, içerik ve operasyon olay geçmişi</small><Link className="button button--ghost" href="/audit">Audit günlüğünü aç</Link></article>
        <article className="is-active"><span>Kalite</span><strong>Manuel QA kuyruğu</strong><small>Sonradan kullanıcı tarafından test edilecek bütün feature senaryoları</small><Link className="button button--primary" href="/qa">Test listesini aç</Link></article>
      </nav>
      <section className="metric-grid" aria-label="Platform özeti"><article><span>Seri</span><strong>{contentCounts.series}</strong></article><article><span>Bölüm</span><strong>{contentCounts.episodes}</strong></article><article><span>Kullanıcı</span><strong>{Number(users?.count ?? 0)}</strong></article><article><span>Kütüphane kaydı</span><strong>{Number(saved?.count ?? 0)}</strong></article><article><span>Aktif ilerleme</span><strong>{Number(progress?.count ?? 0)}</strong></article><article><span>Açık rapor</span><strong>{Number(openReports?.count ?? 0)}</strong></article></section>
      <section className="studio-section"><div className="section-heading"><div><p className="section-kicker">İçerik envanteri</p><h2>Seriler</h2></div><span className="sort-note">D1 katalog</span></div><div className="studio-table" role="table"><div role="row" className="studio-table__head"><span>Seri</span><span>Yayın</span><span>Bölüm</span><span>İşlem</span></div>{seriesCatalog.map((series) => <div role="row" key={series.slug}><span><strong>{series.title}</strong><small>{series.creator}</small></span><span>{series.publicationStatus === "published" ? "Yayında" : series.publicationStatus === "draft" ? "Taslak" : "Arşiv"}</span><span>{series.episodes.length}</span><Link href={`/content/${series.slug}`}>Yönet →</Link></div>)}</div></section>
      <section className="studio-roadmap"><h2>Yükleme akışı</h2><p>Kapak ve panel görselleri Studio hostunda doğrulanıp R2 depolamaya yüklenebilir; sıralama, kapak geri yükleme, süreli taslak önizleme ve responsive WebP kuyruğu hazırdır. Production Queue/Images worker adaptörü kodda hazırdır; canlıya geçmeden binding ve dead-letter kaynağı provision edilir.</p><div><Link className="button button--ghost" href="/media">Medya yükle</Link><Link className="button button--ghost" href={new URL("/production-journal", publicHome).toString()}>Üretim planını oku</Link></div></section>
    </main>
  </div>;
}
