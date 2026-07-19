import Link from "next/link";
import { redirect } from "next/navigation";
import { SiteHeader } from "../../components/SiteHeader";
import { getCurrentUser } from "../../lib/auth";
import { publicSiteUrlForCurrentRequest } from "../../lib/server-site-origins";
import { AUDIT_GROUPS, listAuditEvents, listStudioUsers } from "../../lib/studio-admin";

export const dynamic = "force-dynamic";

const groupLabels: Record<string, string> = { account: "Hesap", admin: "Yönetim", contact: "İletişim", content: "İçerik", copyright: "Telif", library: "Kütüphane", media: "Medya", moderation: "Moderasyon", preview: "Önizleme", review: "Yorum" };
const actionLabels: Record<string, string> = {
  "admin.user_role_changed": "Kullanıcı rolü değiştirildi",
  "admin.invitation_created": "Yönetici daveti oluşturuldu",
  "admin.invitation_resent": "Yönetici daveti yenilendi",
  "admin.invitation_revoked": "Yönetici daveti iptal edildi",
  "admin.invitation_accepted": "Yönetici daveti kabul edildi",
  "admin.bootstrap_completed": "İlk yönetici kurulumu tamamlandı",
  "admin.notification_outbox_purged": "Süresi dolan bildirimler temizlendi",
  "account.logged_in": "Hesaba giriş yapıldı",
  "account.registered": "Hesap oluşturuldu",
  "content.series_created": "Seri oluşturuldu",
  "content.series_updated": "Seri güncellendi",
  "content.episode_created": "Bölüm oluşturuldu",
  "content.episode_updated": "Bölüm güncellendi",
  "media.uploaded": "Medya yüklendi",
  "media.derivative_completed": "Responsive varyant tamamlandı",
  "preview.created": "Taslak önizleme oluşturuldu",
  "preview.revoked": "Taslak önizleme iptal edildi",
  "review.replied": "Yoruma yanıt verildi",
  "review.reply_deleted": "Yorum yanıtı silindi",
  "account.user_blocked": "Kullanıcı engellendi",
  "account.user_unblocked": "Kullanıcı engeli kaldırıldı",
  "moderation.reply_hide": "Yorum yanıtı gizlendi",
  "moderation.reply_publish": "Yorum yanıtı yeniden yayınlandı",
  "copyright.received": "Telif bildirimi alındı",
  "copyright.status_updated": "Telif bildirimi durumu güncellendi",
};

function metadataLabel(key: string) {
  const labels: Record<string, string> = { seriesSlug: "Seri", episodeSlug: "Bölüm", publicationStatus: "Yayın", mediaId: "Medya", mimeType: "MIME", byteSize: "Boyut", width: "Genişlik", height: "Yükseklik", jobs: "İş", jobId: "Kuyruk işi", panelId: "Panel", from: "Önce", to: "Sonra", grantId: "Önizleme", expiresAt: "Bitiş", reviewId: "Yorum", replyId: "Yanıt", reason: "Neden", containsSpoiler: "Spoiler", rating: "Puan", messageId: "Mesaj", role: "Rol", targetUserId: "Hedef kullanıcı", previousRole: "Eski rol", newRole: "Yeni rol", position: "Konum", reportId: "Rapor", invitationId: "Davet", deletedCount: "Silinen kayıt", policyVersion: "Politika sürümü", noticeId: "Telif bildirimi", previousStatus: "Eski durum", newStatus: "Yeni durum" };
  return labels[key] ?? key;
}

function metadataValue(key: string, value: unknown, formatter: Intl.DateTimeFormat) {
  if (key === "expiresAt" && typeof value === "number") return formatter.format(value);
  if (key === "byteSize" && typeof value === "number") return `${Math.ceil(value / 1024)} KB`;
  if (typeof value === "boolean") return value ? "Evet" : "Hayır";
  return String(value);
}

export default async function StudioAuditPage({ searchParams }: { searchParams: Promise<{ group?: string; user?: string; before?: string }> }) {
  const currentUser = await getCurrentUser();
  if (!currentUser) redirect("/login?return_to=/audit");
  if (currentUser.role !== "admin") redirect("/account?error=Studio%20yalnızca%20yönetici%20hesaplarına%20açık.");
  const query = await searchParams;
  const before = query.before ? Number(query.before) : undefined;
  const [result, users, publicHome] = await Promise.all([
    listAuditEvents({ group: query.group, userId: query.user, before }),
    listStudioUsers(),
    publicSiteUrlForCurrentRequest("/"),
  ]);
  const formatter = new Intl.DateTimeFormat("tr-TR", { dateStyle: "medium", timeStyle: "short", timeZone: "Europe/Istanbul" });
  const nextCursor = result.events.at(-1)?.createdAt;
  const nextParams = new URLSearchParams();
  if (query.group) nextParams.set("group", query.group);
  if (query.user) nextParams.set("user", query.user);
  if (nextCursor) nextParams.set("before", String(nextCursor));

  return <div className="site-shell studio-shell"><SiteHeader compact homeHref={publicHome} /><main id="main-content" className="studio-main wrap">
    <div className="studio-top"><div><p className="section-kicker">Operasyon geçmişi</p><h1>Audit günlüğü</h1><p>Hesap, içerik, medya ve moderasyon işlemlerinin değiştirilemez olay kaydı.</p></div><div className="studio-top__actions"><Link className="button button--ghost" href="/">← Studio</Link><Link className="button button--ghost" href="/users">Kullanıcılar</Link></div></div>
    <aside className="studio-notice"><strong>Gizlilik:</strong> Bu görünüm yalnız güvenli allowlist metadata alanlarını gösterir; token, parola özeti, oturum anahtarı ve serbest metin audit ekranına taşınmaz.</aside>
    <form className="audit-filters" action="/audit" method="get">
      <label>Olay grubu<select name="group" defaultValue={query.group ?? ""}><option value="">Tüm olaylar</option>{AUDIT_GROUPS.map((group) => <option key={group} value={group}>{groupLabels[group]}</option>)}</select></label>
      <label>İşlemi yapan<select name="user" defaultValue={query.user ?? ""}><option value="">Tüm aktörler</option>{users.map((user) => <option key={user.id} value={user.id}>{user.displayName} · {user.email}</option>)}</select></label>
      <button className="button button--primary" type="submit">Filtrele</button>
      {(query.group || query.user || query.before) && <Link className="button button--ghost" href="/audit">Filtreleri temizle</Link>}
    </form>
    <section className="studio-section" aria-labelledby="audit-title"><div className="section-heading"><div><p className="section-kicker">En yeni önce</p><h2 id="audit-title">Olaylar</h2></div><span className="sort-note">{result.events.length} kayıt</span></div>
      {result.events.length ? <ol className="audit-list">{result.events.map((event) => <li key={event.id}><article><header><div><span className="pill pill--accent">{groupLabels[event.action.split(".")[0]] ?? "Sistem"}</span><strong>{actionLabels[event.action] ?? event.action.replaceAll("_", " ")}</strong><small>{event.actorName ? `${event.actorName} · ${event.actorEmail}` : "Sistem / anonim"}</small></div><time dateTime={new Date(event.createdAt).toISOString()}>{formatter.format(event.createdAt)}</time></header>{Object.keys(event.metadata).length > 0 && <dl>{Object.entries(event.metadata).map(([key, value]) => <div key={key}><dt>{metadataLabel(key)}</dt><dd>{metadataValue(key, value, formatter)}</dd></div>)}</dl>}<code>{event.action}</code></article></li>)}</ol> : <div className="empty-state"><strong>Bu filtreyle eşleşen olay yok.</strong><p>Filtreleri temizleyerek tüm operasyon geçmişine dönebilirsin.</p>{(query.group || query.user || query.before) && <Link className="button button--primary" href="/audit">Tüm olayları göster</Link>}</div>}
      {result.hasMore && nextCursor && <div className="audit-pagination"><Link className="button button--ghost" href={`/audit?${nextParams.toString()}`}>Daha eski kayıtlar</Link></div>}
    </section>
  </main></div>;
}
