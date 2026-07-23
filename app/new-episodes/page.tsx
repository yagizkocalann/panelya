import type { Metadata } from "next";
import Link from "next/link";
import { SiteFooter } from "../components/SiteFooter";
import { SiteHeader } from "../components/SiteHeader";
import { listPublishedEpisodeUpdates } from "../lib/content-repository";

export const metadata: Metadata = {
  title: "Yeni Eklenen Bölümler — Panelya",
  description: "Panelya'da yeni eklenen webtoon ve dikey çizgi hikâye bölümlerini keşfet.",
  alternates: { canonical: "/new-episodes" },
  openGraph: {
    title: "Yeni Eklenen Bölümler — Panelya",
    description: "Panelya'da yeni eklenen webtoon ve dikey çizgi hikâye bölümlerini keşfet.",
    url: "/new-episodes",
  },
};

export default async function NewEpisodesPage() {
  const updates = await listPublishedEpisodeUpdates(24);

  return (
    <div className="site-shell">
      <SiteHeader />
      <main id="main-content" className="wrap content-wrap route-page">
        <section aria-labelledby="new-episodes-title">
          <div className="section-heading"><div><p className="section-kicker">Okuma akışı</p><h1 id="new-episodes-title">Yeni Eklenen Bölümler</h1><p>En son eklenen bölümler, yayın zamanına göre tek akışta.</p></div><Link className="inline-link" href="/catalog">Tüm Seriler →</Link></div>
          {updates.length ? (
            <div className="update-list">
              {updates.map(({ series, episode }) => (
                <article className="update-card" key={`${series.slug}/${episode.slug}`}>
                  <div className={`update-card__marker update-card__marker--${series.tone}`} aria-hidden="true" />
                  <div className="update-card__body">
                    <p>{episode.publishedAt}</p>
                    <h2><Link href={`/${series.slug}/${episode.slug}`}>{series.title} · Bölüm {episode.number}</Link></h2>
                    <span>{episode.title} · {episode.readTime}</span>
                  </div>
                  <div className="update-card__actions">
                    <Link className="button button--ghost" href={`/${series.slug}`}>Seriyi İncele</Link>
                    <Link className="button button--primary" href={`/${series.slug}/${episode.slug}`}>Bölümü Oku</Link>
                  </div>
                </article>
              ))}
            </div>
          ) : <div className="empty-state"><strong>Henüz yayınlanmış bölüm yok.</strong><p>Yeni bölümler eklendiğinde burada görünecek.</p><Link className="button button--primary" href="/catalog">Kataloğa Dön</Link></div>}
        </section>
      </main>
      <SiteFooter />
    </div>
  );
}
