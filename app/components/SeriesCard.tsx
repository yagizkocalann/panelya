import Link from "next/link";
import type { Series } from "../data/catalog";

export function SeriesCard({ series, badge }: { series: Series; badge?: string }) {
  const coverStyle = series.coverImage
    ? { backgroundImage: `url("${series.coverImage}")`, backgroundPosition: series.coverPosition ?? "center" }
    : undefined;

  return (
    <article className="series-card">
      <Link className={`poster poster--${series.tone}${series.coverImage ? " poster--image" : ""}`} style={coverStyle} href={`/${series.slug}`} aria-label={`${series.title} seri sayfasını aç`}>
        {!series.coverImage && <><span className="poster-orbit poster-orbit--one" aria-hidden="true" /><span className="poster-orbit poster-orbit--two" aria-hidden="true" /><span className="poster-figure" aria-hidden="true"><i /><b /></span></>}
        {badge && <span className="card-badge">{badge}</span>}
        <span className="poster-title">{series.title}</span>
      </Link>
      <div className="series-card__body">
        <div className="card-kicker"><span>{series.genres[0]}</span><span>{series.updatedAt}</span></div>
        <h3><Link href={`/${series.slug}`}>{series.title}</Link></h3>
        <p>{series.eyebrow}</p>
        <div className="card-meta"><span>{series.episodes.length} bölüm</span><span aria-label={`${series.rating} puan`}>★ {series.rating.toFixed(1)}</span></div>
      </div>
    </article>
  );
}
