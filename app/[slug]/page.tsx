import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { SiteFooter } from "../components/SiteFooter";
import { SiteHeader } from "../components/SiteHeader";
import { ReadingProgressCard } from "./ReadingProgressCard";
import { AdTestSlot } from "../components/AdTestSlot";
import { getCurrentUser } from "../lib/auth";
import { getSeriesCommunity } from "../lib/reviews";
import { getPublishedSeries } from "../lib/content-repository";

type SeriesPageProps = { params: Promise<{ slug: string }>; searchParams?: Promise<{ community?: string }> };

const communityMessages: Record<string, string> = {
  "review-saved": "Puanın ve yorumun kaydedildi.",
  "review-deleted": "Değerlendirmen silindi.",
  reported: "Rapor moderasyon kuyruğuna gönderildi.",
  "already-reported": "Bu yorumu daha önce raporladın.",
  "cannot-report-own": "Kendi yorumunu raporlayamazsın; düzenleyebilir veya silebilirsin.",
  "invalid-rating": "1–5 arasında bir puan seç.",
  "invalid-comment": "Yorum boş bırakılabilir; yazılırsa 10–1000 karakter olmalı.",
  "invalid-report": "Rapor nedeni veya açıklaması geçersiz.",
  "rate-limited": "Çok sık değerlendirme güncellendi. Biraz sonra yeniden dene.",
  "report-rate-limited": "Rapor sınırına ulaştın. Daha sonra yeniden dene.",
};

export async function generateMetadata({ params }: SeriesPageProps): Promise<Metadata> {
  const { slug } = await params;
  const series = await getPublishedSeries(slug);
  if (!series) return { title: "Seri bulunamadı — Panelya" };
  return { title: `${series.title} — Panelya`, description: series.description };
}

export default async function SeriesPage({ params, searchParams }: SeriesPageProps) {
  const { slug } = await params;
  const series = await getPublishedSeries(slug);
  if (!series) notFound();
  const user = await getCurrentUser();
  const [community, query] = await Promise.all([getSeriesCommunity(slug, user?.id), searchParams ?? Promise.resolve({})]);
  const ascending = [...series.episodes].sort((a, b) => a.number - b.number);
  const first = ascending[0];
  const latest = ascending[ascending.length - 1];
  const coverStyle = series.coverImage
    ? { backgroundImage: `url("${series.coverImage}")`, backgroundPosition: series.coverPosition ?? "center" }
    : undefined;

  return (
    <div className="site-shell">
      <SiteHeader />
      <main id="main-content" className="series-page">
        <section className="series-hero wrap" aria-labelledby="series-title">
          <div className={`series-cover poster poster--${series.tone}${series.slug === "gece-vardiyasi" ? " series-cover--master" : ""}${series.coverImage ? " poster--image" : ""}`} style={coverStyle}>
            {series.slug !== "gece-vardiyasi" && !series.coverImage && <><span className="poster-orbit poster-orbit--one" aria-hidden="true" /><span className="poster-orbit poster-orbit--two" aria-hidden="true" /><span className="poster-figure poster-figure--large" aria-hidden="true"><i /><b /></span></>}
            <span className="series-cover__word">{series.title}</span>
          </div>
          <div className="series-info">
            <p className="section-kicker">{series.eyebrow}</p>
            <h1 id="series-title">{series.title}</h1>
            <p className="creator-line">{series.creator}</p>
            <div className="series-stats"><span>{series.status}</span><span>★ {(community.average ?? series.rating).toFixed(1)}</span><span>{series.followers} takipçi</span></div>
            <div className="genre-pills">{series.genres.map((genre) => <Link key={genre} href={`/?genre=${encodeURIComponent(genre)}`}>{genre}</Link>)}</div>
            <p className="series-description">{series.longDescription}</p>
            <div className="series-actions">
              <Link className="button button--primary button--large" href={`/${series.slug}/${first.slug}`}>▶ İlk bölümü oku</Link>
              <Link className="button button--glass button--large" href={`/${series.slug}/${latest.slug}`}>Son bölüme git</Link>
              <form action={`/api/library/${series.slug}`} method="post"><input type="hidden" name="action" value="add" /><input type="hidden" name="return_to" value={`/${series.slug}`} /><button type="submit" className="button button--ghost">＋ Kütüphaneye ekle</button></form>
              <form action={`/api/library/${series.slug}`} method="post"><input type="hidden" name="action" value="favorite" /><input type="hidden" name="return_to" value={`/${series.slug}`} /><button type="submit" className="button button--ghost">♡ Favori</button></form>
            </div>
          </div>
        </section>

        <ReadingProgressCard seriesSlug={series.slug} firstEpisodeSlug={first.slug} />
        <div className="wrap series-ad"><AdTestSlot placement="series-detail-01" /></div>

        <section className="episode-section wrap" aria-labelledby="episodes-title">
          <div className="section-heading"><div><p className="section-kicker">{series.episodes.length} durak</p><h2 id="episodes-title">Bölümler</h2></div><span className="sort-note">En yeni önce</span></div>
          <ol className="episode-list">
            {series.episodes.map((episode) => (
              <li key={episode.slug}><Link href={`/${series.slug}/${episode.slug}`}><span className="episode-number">{String(episode.number).padStart(2, "0")}</span><span className="episode-title"><strong>{episode.title}</strong><small>{episode.publishedAt}</small></span><span className="episode-time">{episode.readTime}</span><span className="episode-arrow" aria-hidden="true">→</span></Link></li>
            ))}
          </ol>
        </section>

        <section id="community" className="community-section wrap" aria-labelledby="community-title">
          <div className="community-heading"><div><p className="section-kicker">Okuyucu topluluğu</p><h2 id="community-title">Puanlar ve yorumlar</h2></div><div className="rating-summary"><strong>{community.average?.toFixed(1) ?? "—"}</strong><span aria-label={community.average ? `5 üzerinden ${community.average.toFixed(1)}` : "Henüz puan yok"}>★★★★★</span><small>{community.count ? `${community.count} değerlendirme` : "İlk değerlendirmeyi sen yap"}</small></div></div>
          {query.community && communityMessages[query.community] && <p className={`form-message ${query.community.includes("invalid") || query.community.includes("limited") || query.community === "cannot-report-own" ? "form-message--error" : "form-message--success"}`} role="status">{communityMessages[query.community]}</p>}
          <div className="community-layout">
            <aside className="review-composer">
              <h3>{community.currentReview ? "Değerlendirmeni düzenle" : "Seriyi değerlendir"}</h3>
              {user ? user.emailVerifiedAt ? <>
                {community.currentReview?.status === "hidden" && <p className="moderation-note">Bu yorum moderasyon tarafından gizlendi. Düzenleme otomatik olarak yeniden yayınlamaz.</p>}
                <form className="stack-form" action={`/api/reviews/${series.slug}`} method="post">
                  <label>Puan<select name="rating" defaultValue={community.currentReview?.rating ?? 5} required><option value="5">5 — Çok iyi</option><option value="4">4 — İyi</option><option value="3">3 — Orta</option><option value="2">2 — Zayıf</option><option value="1">1 — Beğenmedim</option></select></label>
                  <label>Yorum<textarea name="comment" defaultValue={community.currentReview?.comment ?? ""} minLength={10} maxLength={1000} rows={6} placeholder="Yorum yazmak isteğe bağlıdır." /><small>Yazılırsa 10–1000 karakter.</small></label>
                  <label className="check-row"><input name="contains_spoiler" type="checkbox" value="yes" defaultChecked={Boolean(community.currentReview?.contains_spoiler)} /> Spoiler içeriyor</label>
                  <button className="button button--primary" type="submit">Değerlendirmeyi kaydet</button>
                </form>
                {community.currentReview && <form className="review-delete-form" action={`/api/reviews/${series.slug}`} method="post"><input type="hidden" name="action" value="delete" /><button className="button button--ghost" type="submit">Değerlendirmemi sil</button></form>}
              </> : <><p>Yorum ve rapor güvenliği için önce e-posta adresini doğrula.</p><Link className="button button--primary" href="/account">Hesap güvenliğine git</Link></> : <><p>Puan vermek, yorum yazmak ve raporlamak için giriş yap.</p><Link className="button button--primary" href={`/login?return_to=${encodeURIComponent(`/${series.slug}#community`)}`}>Giriş yap</Link></>}
            </aside>
            <div className="review-list" aria-label="Okuyucu yorumları">{community.reviews.length ? community.reviews.map((review) => <article className="review-card" key={review.id}><header><div><strong>{review.display_name}</strong><span aria-label={`5 üzerinden ${review.rating}`}>{"★".repeat(review.rating)}{"☆".repeat(5 - review.rating)}</span></div><time dateTime={new Date(review.updated_at).toISOString()}>{new Intl.DateTimeFormat("tr-TR", { dateStyle: "medium" }).format(new Date(review.updated_at))}</time></header>
              {review.comment ? review.contains_spoiler ? <details className="spoiler-comment"><summary>Spoiler içerir — yorumu göster</summary><p>{review.comment}</p></details> : <p>{review.comment}</p> : <p className="rating-only">Yalnızca puan verdi.</p>}
              {user && user.id !== review.user_id && user.emailVerifiedAt && <details className="report-panel"><summary>Yorumu raporla</summary><form className="stack-form" action={`/api/review-reports/${review.id}`} method="post"><label>Neden<select name="reason" defaultValue="spam"><option value="spam">Spam veya reklam</option><option value="harassment">Taciz veya nefret</option><option value="spoiler">İşaretlenmemiş spoiler</option><option value="copyright">Telif ihlali</option><option value="other">Diğer</option></select></label><label>Ek açıklama<textarea name="details" maxLength={500} rows={3} /></label><button className="button button--ghost" type="submit">Raporu gönder</button></form></details>}
            </article>) : <div className="empty-state"><strong>Henüz değerlendirme yok.</strong><p>Bu seri için ilk puanı ve yorumu bırakabilirsin.</p></div>}</div>
          </div>
        </section>
      </main>
      <SiteFooter />
    </div>
  );
}
