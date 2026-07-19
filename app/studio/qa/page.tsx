import Link from "next/link";
import { redirect } from "next/navigation";
import { RecentAuthenticationNotice, recentAuthenticationHref } from "../../components/RecentAuthenticationNotice";
import { SiteHeader } from "../../components/SiteHeader";
import { getCurrentUser, hasRecentAuthentication } from "../../lib/auth";
import { getLocalQaFixtureStatus, localQaFixtureAccounts, LOCAL_QA_FIXTURE_VERSION } from "../../lib/local-qa-fixtures";
import { getPlatformReadiness, type PlatformCheckStatus } from "../../lib/platform-readiness";
import { currentRequestIsLocalQa, publicSiteUrlForCurrentRequest } from "../../lib/server-site-origins";

export const dynamic = "force-dynamic";

const priorityChecks = [
  { id: "QA-ADM-01", title: "Yönetici davetini kabul etme", path: "/users → /outbox", result: "Yeni test yöneticisi oluşmalı, Studio oturumu açılmalı ve davet kabul edildi görünmeli." },
  { id: "QA-STU-06", title: "Outbox saklama ve temizleme", path: "/outbox", result: "Yalnız süresi dolan sentetik kayıtlar temizlenmeli; aktif bağlantılar kalmalı ve audit yazılmalı." },
  { id: "QA-MED-02", title: "Production responsive kuyruk teslimi", path: "/media + Queue test ortamı", result: "İş worker'a teslim edilmeli; eksik binding başarılı görünmemeli ve yeniden gönderme kopya varyant oluşturmamalı." },
  { id: "QA-SEC-01", title: "Dağıtık rate-limit modu", path: "/qa + hassas auth uçları", result: "Yerelde atomik D1, production testinde Cloudflare edge + D1 görünmeli; eksik binding mutation'ı güvenli biçimde reddetmeli." },
  { id: "QA-SEC-02", title: "Oturum süresi ve yeniden doğrulama", path: "Public /account/sessions + Studio hassas işlemler", result: "Public/Studio oturum kapsamı ayrılmalı; Studio 30 dakika idle durumda kapanmalı, 10 dakikadan eski doğrulamada hassas kontroller şifre istemeli ve başarılı doğrulama yalnız mevcut tokeni yenilemelidir." },
  { id: "QA-DATA-01", title: "Yerel QA veri paketi", path: "/qa", result: "Sentetik paket ikinci kurulumda kopya üretmemeli; sıfırlama yalnız QA ad alanını kaldırırken yönetici, normal hesaplar ve özgün katalog korunmalıdır." },
  { id: "QA-OPS-01", title: "Production platform hazırlığı", path: "/qa + /api/admin/platform-readiness", result: "Otomatik binding kontrolleri hazır olmalı; Queue consumer retry ve dead-letter politikası ayrıca doğrulanmalı." },
  { id: "QA-OPS-02", title: "D1/R2 kurtarma tatbikatı", path: "docs/backup-restore-runbook.md + izole test kaynakları", result: "Doğrulanmış paket yeni D1/R2 test kaynaklarına dönmeli; katalog ve medya smoke geçmeli, eski oturum/token/linkler kullanılamamalıdır." },
  { id: "QA-FOL-01", title: "Takip ve yeni bölüm bildirimi", path: "Public seri + /library → Studio /content + /outbox", result: "Yalnız bildirimi açık, doğrulanmış takipçi tek yeni bölüm kaydı almalı; yeniden kaydetme kopya üretmemeli ve aktif durumlar hesapla eşleşmelidir." },
  { id: "QA-CAT-01", title: "Katalog keşfi ve cursor", path: "Public /?view=catalog", result: "Türkçe arama, tür/durum filtresi, üç sıralama ve cursor sayfaları aynı D1 yayın kümesinde tekrarsız kalmalı; bozuk cursor güvenli biçimde ilk sayfaya dönmelidir." },
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

const fixtureMessages: Record<string, string> = {
  seeded: "Yerel QA veri paketi kuruldu ve önceki sentetik kayıtlar güvenli başlangıç durumuna döndürüldü.",
  reset: "Yerel QA veri paketi kaldırıldı. Mevcut yönetici ve normal kullanıcı kayıtları korunmuştur.",
};

export default async function StudioQaPage({ searchParams }: { searchParams: Promise<{ error?: string; fixtures?: string }> }) {
  const user = await getCurrentUser();
  if (!user) redirect("/login?return_to=/qa");
  if (user.role !== "admin") redirect("/account?error=Studio%20yalnızca%20yönetici%20hesaplarına%20açık.");
  const [publicHome, readiness, isLocalQa, recentlyAuthenticated, query] = await Promise.all([
    publicSiteUrlForCurrentRequest("/"),
    getPlatformReadiness(),
    currentRequestIsLocalQa(),
    hasRecentAuthentication(),
    searchParams,
  ]);
  const fixtureStatus = isLocalQa ? await getLocalQaFixtureStatus() : null;
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
    {query.error && <p className="form-message form-message--error" role="alert">{query.error}</p>}
    {query.fixtures && fixtureMessages[query.fixtures] && <p className="form-message form-message--success" role="status">{fixtureMessages[query.fixtures]}</p>}
    {isLocalQa && fixtureStatus && <section className="studio-section qa-fixture-section" aria-labelledby="qa-fixture-title">
      <div className="section-heading"><div><p className="section-kicker">Tekrarlanabilir yerel başlangıç</p><h2 id="qa-fixture-title">QA veri paketi</h2><p>Sürüm {LOCAL_QA_FIXTURE_VERSION} · yalnız <code>qa_fixture_*</code> kimlikli sentetik kayıtları yönetir.</p></div><span className={`pill${fixtureStatus.ready ? " pill--accent" : ""}`}>{fixtureStatus.ready ? "HAZIR" : "KURULMADI"}</span></div>
      <div className="qa-fixture-metrics" aria-label="QA veri paketi özeti">
        <div><strong>{fixtureStatus.users}</strong><span>okuyucu</span></div><div><strong>{fixtureStatus.series}</strong><span>seri</span></div><div><strong>{fixtureStatus.episodes}</strong><span>bölüm</span></div><div><strong>{fixtureStatus.reviews}</strong><span>yorum</span></div><div><strong>{fixtureStatus.reports}</strong><span>açık rapor</span></div><div><strong>{fixtureStatus.outbox}</strong><span>bildirim</span></div>
      </div>
      <div className="qa-fixture-layout">
        <article className="settings-card"><h3>Paketi kur veya yenile</h3><p>Üç sentetik okuyucu, sekiz yayınlanmış ve iki görünürlük testi serisi; kütüphane, ilerleme, topluluk, moderasyon, mesaj ve outbox kayıtları oluşturur.</p>
          {recentlyAuthenticated ? <form className="stack-form" action="/api/admin/qa-fixtures" method="post">
            <input type="hidden" name="action" value="seed" />
            <label>Test hesaplarının ortak parolası<input name="fixture_password" type="password" autoComplete="new-password" minLength={10} maxLength={128} required /><small>Parola yalnız hashlenerek sentetik hesaplara yazılır; sayfada, audit kaydında veya dokümanda saklanmaz.</small></label>
            <button className="button button--primary" type="submit">QA paketini kur / yenile</button>
          </form> : <><RecentAuthenticationNotice returnTo="/qa" /><Link className="button button--primary" href={recentAuthenticationHref("/qa")}>Şifreni doğrula</Link></>}
        </article>
        <article className="settings-card settings-card--danger"><h3>Sentetik veriyi kaldır</h3><p>Yalnız QA ad alanındaki hesapları ve ilişkili sentetik kayıtları siler. Mevcut yönetici hesabını, normal kullanıcıları ve özgün katalog serilerini değiştirmez.</p>
          {recentlyAuthenticated ? <form action="/api/admin/qa-fixtures" method="post"><input type="hidden" name="action" value="reset" /><button className="button button--danger" type="submit">QA verisini sıfırla</button></form> : <Link className="button button--ghost" href={recentAuthenticationHref("/qa")}>Sıfırlama için doğrula</Link>}
        </article>
      </div>
      <div className="qa-fixture-accounts"><div><h3>Hazır test hesapları</h3><p>Kurulum sırasında belirlediğin ortak parola ile public giriş ekranından kullanılır.</p></div><ul>{localQaFixtureAccounts.map((account) => <li key={account.id}><span><strong>{account.displayName}</strong><code>{account.email}</code></span><span className={`pill${account.verified ? " pill--accent" : ""}`}>{account.verified ? "Doğrulandı" : "Doğrulanmadı"}</span></li>)}</ul></div>
      <nav className="qa-fixture-links" aria-label="QA verisi hızlı bağlantıları"><a className="button button--ghost" href={publicHome}>Public kataloğu aç</a><Link className="button button--ghost" href="/users">Kullanıcılar</Link><Link className="button button--ghost" href="/moderation">Moderasyon</Link><Link className="button button--ghost" href="/messages">Mesajlar</Link><Link className="button button--ghost" href="/outbox">Outbox</Link></nav>
    </section>}
    <section className="studio-section" aria-labelledby="platform-readiness-title"><div className="section-heading"><div><p className="section-kicker">Deployment güvenlik kapısı</p><h2 id="platform-readiness-title">Platform hazırlığı</h2><p>{profileLabel} profili · {readiness.automatedReady ? "otomatik kontroller hazır" : "otomatik kontroller tamamlanmadı"}{readiness.manualVerificationRequired ? " · dış Queue/DLQ doğrulaması gerekli" : ""}</p></div><span className="sort-note">{readiness.checks.length} kontrol</span></div>
      <div className="message-list">{readiness.checks.map((check) => <article className="message-card" key={check.id}><header><div><span className={`pill${check.status === "ready" ? " pill--accent" : ""}`}>{statusLabels[check.status]}</span><strong>{check.label}</strong><span>{check.required ? "Zorunlu" : "Bilgi"}</span></div></header><p>{check.detail}</p></article>)}</div>
    </section>
    <section className="studio-section" aria-labelledby="qa-priority-title"><div className="section-heading"><div><p className="section-kicker">Kullanıcı testi bekliyor</p><h2 id="qa-priority-title">Öncelikli kontroller</h2></div><span className="sort-note">{priorityChecks.length} hatırlatma</span></div>
      <div className="message-list">{priorityChecks.map((check) => <article className="message-card" key={check.id}><header><div><span className="pill pill--accent">BEKLİYOR</span><strong>{check.id} · {check.title}</strong><span>{check.path}</span></div></header><p>{check.result}</p></article>)}</div>
    </section>
  </main></div>;
}
