import Link from "next/link";
import { redirect } from "next/navigation";
import { RecentAuthenticationNotice, recentAuthenticationHref } from "../../components/RecentAuthenticationNotice";
import { SiteHeader } from "../../components/SiteHeader";
import { getCurrentUser, hasRecentAuthentication } from "../../lib/auth";
import { getPlatformReadiness, type PlatformCheckStatus } from "../../lib/platform-readiness";
import { publicSiteUrlForCurrentRequest } from "../../lib/server-site-origins";
import { getTransientDataMaintenanceSummary } from "../../lib/transient-data-maintenance";

export const dynamic = "force-dynamic";

const priorityChecks = [
  { id: "QA-ADM-01", title: "Yönetici davetini kabul etme", path: "/users → /outbox", result: "Yeni test yöneticisi oluşmalı, Studio oturumu açılmalı ve davet kabul edildi görünmeli." },
  { id: "QA-STU-06", title: "Outbox saklama ve temizleme", path: "/outbox", result: "Yalnız süresi dolan sentetik kayıtlar temizlenmeli; aktif bağlantılar kalmalı ve audit yazılmalı." },
  { id: "QA-MED-02", title: "Production responsive kuyruk teslimi", path: "/media + Queue test ortamı", result: "İş worker'a teslim edilmeli; eksik binding başarılı görünmemeli ve yeniden gönderme kopya varyant oluşturmamalı." },
  { id: "QA-SEC-01", title: "Dağıtık rate-limit modu", path: "/qa + hassas auth uçları", result: "Yerelde atomik D1, production testinde Cloudflare edge + D1 görünmeli; eksik binding mutation'ı güvenli biçimde reddetmeli." },
  { id: "QA-SEC-02", title: "Oturum süresi ve yeniden doğrulama", path: "Public /account/sessions + Studio hassas işlemler", result: "Public/Studio oturum kapsamı ayrılmalı; Studio 30 dakika idle durumda kapanmalı, 10 dakikadan eski doğrulamada hassas kontroller şifre istemeli ve başarılı doğrulama yalnız mevcut tokeni yenilemelidir." },
  { id: "QA-OPS-01", title: "Production platform hazırlığı", path: "/qa + /api/admin/platform-readiness", result: "Otomatik binding kontrolleri hazır olmalı; Queue consumer retry ve dead-letter politikası ayrıca doğrulanmalı." },
  { id: "QA-OPS-02", title: "D1/R2 kurtarma tatbikatı", path: "docs/backup-restore-runbook.md + izole test kaynakları", result: "Doğrulanmış paket yeni D1/R2 test kaynaklarına dönmeli; katalog ve medya smoke geçmeli, eski oturum/token/linkler kullanılamamalıdır." },
  { id: "QA-FOL-01", title: "Takip ve yeni bölüm bildirimi", path: "Public seri + /library → Studio /content + /outbox", result: "Yalnız bildirimi açık, doğrulanmış takipçi tek yeni bölüm kaydı almalı; yeniden kaydetme kopya üretmemeli ve aktif durumlar hesapla eşleşmelidir." },
  { id: "QA-NAV-01", title: "Public bilgi mimarisi", path: "Public / + /catalog + /new-episodes", result: "Ana sayfa editorial kalmalı; üstteki tür dizini kataloğa, yeni bölüm CTA'ları yeni bölüm akışına gitmeli; eski katalog ve /updates URL'leri hedeflerini koruyarak yönlenmelidir." },
  { id: "QA-CAT-01", title: "Katalog keşfi ve numaralı sayfalama", path: "Public /catalog", result: "8/16/32 sayfa boyutu, filtreyi koruyan 1/2/3 sayfaları ve header'dan seçilen türün formda görünmesi doğrulanmalı; Keşfet menüsü alan dışı tıklama ve Escape ile kapanmalıdır." },
  { id: "QA-NEW-01", title: "Otomatik yeni seri penceresi", path: "Studio /content + Public / + /new-series", result: "İlk public yayından sonra ana sayfa ve ayrı yeni-seriler ekranında 30 gün görünmeli; tam 30 gün sınırında kaybolmalı, arşivleyip yeniden yayınlama süreyi sıfırlamamalıdır." },
  { id: "QA-COMM-02", title: "Yanıt, beğeni ve kullanıcı engelleme", path: "Public seri + /account + Studio /moderation", result: "İki doğrulanmış hesapla yanıt/beğeni geri alma ve engelleme/engel kaldırma çalışmalı; engel iki yönlü etkileşimi kesmeli, başka okuyuculara global ban etkisi yapmamalıdır." },
  { id: "QA-COPY-01", title: "Telif bildirimi ve gizli durum takibi", path: "Public /copyright/report + Studio /messages", result: "Bildirim gizli durum bağlantısı üretmeli; Studio durum/public yanıt değişiklikleri linke yansımalı, kişisel ve serbest başvuru verisi audit veya public görünüme sızmamalıdır." },
  { id: "QA-SEO-01", title: "Public SEO ve tarama sınırı", path: "Public robots/sitemap/seri + Studio robots", result: "Production public origin canonical ve sitemap'te aynı olmalı; okuyucu noindex kalmalı, Studio taraması kapanmalı ve JSON-LD yalnız yayın verisini anlatmalıdır." },
  { id: "QA-RESP-01", title: "Responsive genel tur", path: "Public + Studio", result: "1440, 1024, 768, 390 ve 360 px'te taşma, kırpılma veya 44 px altı dokunma hedefi olmamalı." },
] as const;

const statusLabels: Record<PlatformCheckStatus, string> = {
  ready: "HAZIR",
  missing: "EKSİK",
  not_required: "BU PROFİLDE GEREKMİYOR",
  manual: "ELLE DOĞRULA",
  misconfigured: "UYUMSUZ",
};

const maintenanceLabels = {
  sessions: "Oturum",
  accountTokens: "Hesap anahtarı",
  reauthenticationRequests: "Yeniden doğrulama isteği",
  reauthenticationTokens: "Yeniden doğrulama kanıtı",
  previewTokens: "Önizleme anahtarı",
  rateLimitBuckets: "Kota kovası",
  notificationOutbox: "Outbox kaydı",
} as const;

export default async function StudioQaPage({ searchParams }: { searchParams: Promise<{ error?: string; maintenance?: string; count?: string }> }) {
  const user = await getCurrentUser();
  if (!user) redirect("/login?return_to=/qa");
  if (user.role !== "admin") redirect("/account?error=Studio%20yalnızca%20yönetici%20hesaplarına%20açık.");
  const [publicHome, readiness, maintenance, recentlyAuthenticated, query] = await Promise.all([
    publicSiteUrlForCurrentRequest("/"),
    getPlatformReadiness(),
    getTransientDataMaintenanceSummary(),
    hasRecentAuthentication(),
    searchParams,
  ]);
  const deletedCount = Math.max(0, Number.parseInt(query.count ?? "0", 10) || 0);
  const edgeCheck = readiness.checks.find((check) => check.id === "binding-rate-limit");
  const rateLimitLabel = readiness.modes.rateLimit === "invalid"
    ? "Rate-limit modu uyumsuz; korunan mutation’lar kapalı"
    : readiness.modes.rateLimit === "cloudflare_hybrid" && edgeCheck?.status !== "ready"
    ? "Yapılandırma kullanılamıyor; korunan mutation’lar kapalı"
    : readiness.modes.rateLimit === "cloudflare_hybrid"
      ? "Cloudflare edge ani trafik kalkanı + atomik D1 kesin kota"
      : "Atomik D1 kesin kota (yerel/test modu)";
  const profileLabel = readiness.profile === "production" ? "Production" : readiness.profile === "local" ? "Yerel/test" : "Uyumsuz karma";

  return <div className="site-shell studio-shell"><SiteHeader compact homeHref={publicHome} /><main id="main-content" className="studio-main wrap">
    <div className="studio-top"><div><p className="section-kicker">Kalıcı hatırlatma</p><h1>Manuel QA kuyruğu</h1><p>Otomatik testten geçse bile senin daha sonra elle görmen gereken feature’lar burada hatırlatılır.</p></div><Link className="button button--ghost" href="/">← Studio</Link></div>
    <aside className="studio-notice"><strong>Tek kayıt kaynağı:</strong> Ayrıntılı senaryolar repodaki <code>docs/manual-qa-checklist.md</code> dosyasında tutulur. Yeni feature bu listeye eklenmeden tamamlanmış sayılmaz.</aside>
    <aside className="studio-notice" role={!readiness.automatedReady ? "alert" : undefined}><strong>Kötüye kullanım koruması:</strong> {rateLimitLabel}.</aside>
    {!recentlyAuthenticated && <RecentAuthenticationNotice returnTo="/qa" />}
    {query.error && <p className="form-message form-message--error" role="alert">{query.error}</p>}
    {query.maintenance === "purged" && <p className="form-message form-message--success" role="status">Geçici veri bakımı tamamlandı; {deletedCount} süresi dolan kayıt silindi.</p>}
    <section className="studio-section outbox-retention" aria-labelledby="transient-maintenance-title"><div className="section-heading"><div><p className="section-kicker">Günlük bakım · Politika v{maintenance.policyVersion}</p><h2 id="transient-maintenance-title">Geçici veri minimizasyonu</h2><p>Yalnız teknik süresi dolmuş oturum, anahtar, yeniden doğrulama, önizleme, kota ve outbox kayıtları temizlenir.</p></div><span className="sort-note">{maintenance.total} temizlenebilir</span></div>
      <div className="outbox-retention__layout"><div className="outbox-retention__metrics">{Object.entries(maintenance.counts).filter(([, count]) => count > 0).map(([category, count]) => <article key={category}><span>{maintenanceLabels[category as keyof typeof maintenanceLabels]}</span><strong>{count}</strong></article>)}</div>
        <div className="outbox-retention__policy"><p>Production Worker her gün UTC 03:17 saatinde aynı sürümlü politikayı çalıştırır. Bu düğme yalnız operasyonel yedek ve QA içindir; audit kaydına kişi verisi yazılmaz.</p>
          {maintenance.total > 0 ? recentlyAuthenticated ? <form action="/api/admin/maintenance/transient-data" method="post"><input type="hidden" name="action" value="purge_expired" /><button className="button button--danger" type="submit">Süresi dolan geçici kayıtları temizle</button></form> : <Link className="button button--ghost" href={recentAuthenticationHref("/qa")}>Bakım için şifreni doğrula</Link> : <p className="retention-current">Şu anda süresi dolmuş geçici kayıt yok.</p>}
        </div></div>
    </section>
    <section className="studio-section" aria-labelledby="platform-readiness-title"><div className="section-heading"><div><p className="section-kicker">Deployment güvenlik kapısı</p><h2 id="platform-readiness-title">Platform hazırlığı</h2><p>{profileLabel} profili · {readiness.automatedReady ? "otomatik kontroller hazır" : "otomatik kontroller tamamlanmadı"}{readiness.manualVerificationRequired ? " · dış Queue/DLQ doğrulaması gerekli" : ""}</p></div><span className="sort-note">{readiness.checks.length} kontrol</span></div>
      <div className="message-list">{readiness.checks.map((check) => <article className="message-card" key={check.id}><header><div><span className={`pill${check.status === "ready" ? " pill--accent" : ""}`}>{statusLabels[check.status]}</span><strong>{check.label}</strong><span>{check.required ? "Zorunlu" : "Bilgi"}</span></div></header><p>{check.detail}</p></article>)}</div>
    </section>
    <section className="studio-section" aria-labelledby="qa-priority-title"><div className="section-heading"><div><p className="section-kicker">Kullanıcı testi bekliyor</p><h2 id="qa-priority-title">Öncelikli kontroller</h2></div><span className="sort-note">{priorityChecks.length} hatırlatma</span></div>
      <div className="message-list">{priorityChecks.map((check) => <article className="message-card" key={check.id}><header><div><span className="pill pill--accent">BEKLİYOR</span><strong>{check.id} · {check.title}</strong><span>{check.path}</span></div></header><p>{check.result}</p></article>)}</div>
    </section>
  </main></div>;
}
