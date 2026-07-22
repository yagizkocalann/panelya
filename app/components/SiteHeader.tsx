import Link from "next/link";
import { listPublishedGenres } from "../lib/content-repository";
import { AuthActions } from "./AuthActions";
import { GenreMenu } from "./GenreMenu";

export async function SiteHeader({ compact = false, homeHref = "/", studioHref = "/studio" }: { compact?: boolean; homeHref?: string; studioHref?: string }) {
  const genres = compact ? [] : await listPublishedGenres();
  return (
    <header className={`site-header${compact ? " site-header--compact" : ""}`}>
      <a className="skip-link" href="#main-content">İçeriğe geç</a>
      <div className="header-inner">
        <Link className="brand" href={homeHref} aria-label="Panelya ana sayfa">
          <span className="brand-mark" aria-hidden="true"><i /><i /><i /></span>
          <span>panelya</span>
        </Link>
        {!compact && <GenreMenu genres={genres} />}
        {!compact && (
          <form className="search" action="/catalog" role="search">
            <label className="sr-only" htmlFor="series-search">Seri ara</label>
            <input id="series-search" name="q" type="search" placeholder="Bir hikâye ara..." autoComplete="off" />
            <button type="submit" aria-label="Ara">Ara</button>
          </form>
        )}
        <nav className="header-actions" aria-label="Hesap">
          {!compact && <Link className="text-link" href="/updates">Yeni bölümler</Link>}
          <AuthActions compact={compact} studioHref={studioHref} />
        </nav>
      </div>
    </header>
  );
}
