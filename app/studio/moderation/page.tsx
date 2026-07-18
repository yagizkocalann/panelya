import Link from "next/link";
import { redirect } from "next/navigation";
import { SiteHeader } from "../../components/SiteHeader";
import { getCurrentUser } from "../../lib/auth";
import { getDatabase } from "../../lib/database";
import { listStudioSeries } from "../../lib/content-repository";
import { publicSiteUrlForCurrentRequest } from "../../lib/server-site-origins";

export const dynamic = "force-dynamic";

type ReportQueueRow = {
  id: string;
  review_id: string;
  reason: string;
  details: string | null;
  report_status: "open" | "resolved" | "dismissed";
  created_at: number;
  series_slug: string;
  rating: number;
  comment: string | null;
  review_status: "published" | "hidden";
  author_name: string;
  reporter_name: string;
};

type ModerationReviewRow = {
  id: string;
  series_slug: string;
  rating: number;
  comment: string | null;
  status: "published" | "hidden";
  updated_at: number;
  author_name: string;
  report_count: number;
};

const reasonLabels: Record<string, string> = { spam: "Spam veya reklam", harassment: "Taciz veya nefret", spoiler: "İşaretlenmemiş spoiler", copyright: "Telif ihlali", other: "Diğer" };

export default async function ModerationPage() {
  const user = await getCurrentUser();
  if (!user) redirect("/login?return_to=/moderation");
  if (user.role !== "admin") redirect("/account?error=Studio%20yalnızca%20yönetici%20hesaplarına%20açık.");
  const [publicHome, contentSeries] = await Promise.all([publicSiteUrlForCurrentRequest("/"), listStudioSeries()]);
  const seriesNames = new Map(contentSeries.map((series) => [series.slug, series.title]));
  const db = await getDatabase();
  const [reports, reviews] = await Promise.all([
    db.prepare(`SELECT rr.id, rr.review_id, rr.reason, rr.details, rr.status AS report_status, rr.created_at,
      r.series_slug, r.rating, r.comment, r.status AS review_status,
      author.display_name AS author_name, reporter.display_name AS reporter_name
      FROM review_reports rr
      JOIN reviews r ON r.id = rr.review_id
      JOIN users author ON author.id = r.user_id
      JOIN users reporter ON reporter.id = rr.reporter_user_id
      ORDER BY CASE rr.status WHEN 'open' THEN 0 ELSE 1 END, rr.created_at DESC LIMIT 100`).all<ReportQueueRow>(),
    db.prepare(`SELECT r.id, r.series_slug, r.rating, r.comment, r.status, r.updated_at, u.display_name AS author_name,
      COUNT(rr.id) AS report_count
      FROM reviews r JOIN users u ON u.id = r.user_id
      LEFT JOIN review_reports rr ON rr.review_id = r.id
      GROUP BY r.id ORDER BY r.updated_at DESC LIMIT 100`).all<ModerationReviewRow>(),
  ]);
  return <div className="site-shell studio-shell"><SiteHeader compact homeHref={publicHome} /><main id="main-content" className="studio-main wrap">
    <div className="studio-top"><div><p className="section-kicker">Topluluk güvenliği</p><h1>Moderasyon</h1><p>Okuyucu raporlarını değerlendir, yorumu gizle veya yanlış raporu kapat.</p></div><Link className="button button--ghost" href="/">← Studio</Link></div>
    <section className="moderation-section" aria-labelledby="report-queue-title"><div className="section-heading"><div><p className="section-kicker">Rapor kuyruğu</p><h2 id="report-queue-title">İnceleme bekleyenler</h2></div><span className="sort-note">{reports.results.filter((item) => item.report_status === "open").length} açık rapor</span></div>
      <div className="moderation-list">{reports.results.length ? reports.results.map((item) => <article className={`moderation-card${item.report_status !== "open" ? " is-closed" : ""}`} key={item.id}><header><div><span className="pill pill--accent">{reasonLabels[item.reason] ?? item.reason}</span><strong>{seriesNames.get(item.series_slug) ?? item.series_slug}</strong><span>{item.report_status === "open" ? "Açık" : item.report_status === "resolved" ? "Çözüldü" : "Reddedildi"}</span></div><time dateTime={new Date(item.created_at).toISOString()}>{new Intl.DateTimeFormat("tr-TR", { dateStyle: "medium", timeStyle: "short" }).format(new Date(item.created_at))}</time></header><p><strong>Yorum sahibi:</strong> {item.author_name} · {item.rating}/5</p><blockquote>{item.comment ?? "Yalnızca puan verilmiş."}</blockquote><p><strong>Raporlayan:</strong> {item.reporter_name}{item.details ? ` · ${item.details}` : ""}</p>{item.report_status === "open" && <div className="moderation-actions"><form action={`/api/admin/moderation/reviews/${item.review_id}`} method="post"><input type="hidden" name="action" value="hide" /><button className="button button--danger" type="submit">Yorumu gizle ve çöz</button></form><form action={`/api/admin/moderation/reports/${item.id}`} method="post"><input type="hidden" name="action" value="dismiss" /><button className="button button--ghost" type="submit">Raporu reddet</button></form></div>}</article>) : <div className="empty-state"><strong>Rapor kuyruğu boş.</strong><p>Okuyucu raporları burada görünecek.</p></div>}</div>
    </section>
    <section className="moderation-section" aria-labelledby="all-reviews-title"><div className="section-heading"><div><p className="section-kicker">İçerik durumu</p><h2 id="all-reviews-title">Son değerlendirmeler</h2></div><span className="sort-note">{reviews.results.length} kayıt</span></div>
      <div className="moderation-review-table">{reviews.results.length ? reviews.results.map((item) => <article key={item.id}><div><span className={`pill${item.status === "published" ? " pill--accent" : ""}`}>{item.status === "published" ? "Yayında" : "Gizli"}</span><strong>{item.author_name} · {item.rating}/5</strong><small>{seriesNames.get(item.series_slug) ?? item.series_slug} · {Number(item.report_count)} rapor</small><p>{item.comment ?? "Yalnızca puan verilmiş."}</p></div><form action={`/api/admin/moderation/reviews/${item.id}`} method="post"><input type="hidden" name="action" value={item.status === "published" ? "hide" : "publish"} /><button className="button button--ghost" type="submit">{item.status === "published" ? "Gizle" : "Yeniden yayınla"}</button></form></article>) : <div className="empty-state"><strong>Henüz değerlendirme yok.</strong></div>}</div>
    </section>
  </main></div>;
}
