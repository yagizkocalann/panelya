import type { Metadata } from "next";
import Link from "next/link";
import { SiteFooter } from "../components/SiteFooter";
import { SiteHeader } from "../components/SiteHeader";
import { listPublishedEpisodeUpdates } from "../lib/content-repository";

export const metadata: Metadata = {
  title: "Yeni bölümler — Panelya",
  description: "Panelya'da son yayınlanan webtoon ve dikey çizgi hikâye bölümlerini keşfet.",
  alternates: { canonical: "/updates" },
  openGraph: {
    title: "Yeni bölümler — Panelya",
    description: "Panelya'da son yayınlanan webtoon ve dikey çizgi hikâye bölümlerini keşfet.",
    url: "/updates",
  },
};

export default async function UpdatesPage() {
  const updates = await listPublishedEpisodeUpdates(24);

  return (
    <div className="site-shell">
      <SiteHeader />
      <main id="main-content" className="wrap content-wrap route-page">
        <section aria-labelledby="updates-title">
          <div className="section-heading"><div><p className="section-kicker">Okuma akışı</p><h1 id="updates-title">Yeni bölümler</h1><p>En son yayınlanan bölümler, en yeni güncellemeden başlayarak tek akışta.</p></div><Link className="inline-link" href="/catalog">Tüm seriler →</Link></div>
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
                    <Link className="button button--ghost" href={`/${series.slug}`}>Seriyi incele</Link>
                    <Link className="button button--primary" href={`/${series.slug}/${episode.slug}`}>Bölümü oku</Link>
                  </div>
                </article>
              ))}
            </div>
          ) : <div className="empty-state"><strong>Henüz yayınlanmış bölüm yok.</strong><p>Yeni bölümler yayınlandığında burada görünecek.</p><Link className="button button--primary" href="/catalog">Kataloğa dön</Link></div>}
        </section>
      </main>
      <SiteFooter />
    </div>
  );
}
