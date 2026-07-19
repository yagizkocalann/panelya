import Link from "next/link";
import { hasRecentAuthentication } from "../../lib/auth";
import type { PreviewGrant } from "../../lib/preview-tokens";

type PreviewScope = {
  seriesSlug: string;
  episodeSlug?: string;
  returnTo: string;
};

function hiddenScopeFields({ seriesSlug, episodeSlug, returnTo }: PreviewScope) {
  return <>
    <input type="hidden" name="series_slug" value={seriesSlug} />
    {episodeSlug && <input type="hidden" name="episode_slug" value={episodeSlug} />}
    <input type="hidden" name="return_to" value={returnTo} />
  </>;
}

function reauthenticateHref(returnTo: string) {
  return `/reauthenticate?return_to=${encodeURIComponent(returnTo)}`;
}

export async function PreviewCreateForm({ seriesSlug, episodeSlug, returnTo }: PreviewScope) {
  if (!(await hasRecentAuthentication())) return <Link className="button button--primary" href={reauthenticateHref(returnTo)}>Şifreni doğrula</Link>;
  return <form action="/api/admin/previews" method="post" target="_blank">
    <input type="hidden" name="action" value="create" />
    {hiddenScopeFields({ seriesSlug, episodeSlug, returnTo })}
    <button className="button button--primary" type="submit">Taslağı önizle ↗</button>
  </form>;
}

export async function PreviewAccessPanel({ grants, seriesSlug, episodeSlug, returnTo }: PreviewScope & { grants: PreviewGrant[] }) {
  const formatter = new Intl.DateTimeFormat("tr-TR", { dateStyle: "short", timeStyle: "short", timeZone: "Europe/Istanbul" });
  const recentlyAuthenticated = await hasRecentAuthentication();

  return <section className="studio-section preview-access" aria-labelledby="preview-access-title">
    <div className="section-heading"><div><p className="section-kicker">Güvenli paylaşım</p><h2 id="preview-access-title">Taslak önizleme bağlantıları</h2></div><span className="sort-note">30 dakika geçerli</span></div>
    <p className="studio-inline-note">Her bağlantı yalnız bu {episodeSlug ? "bölümü" : "seriyi"} açar. Ham anahtar saklanmaz; süresi dolmadan Studio üzerinden iptal edilebilir. Oluşturma ve iptal için son 10 dakika içinde şifre doğrulaması gerekir.</p>
    {grants.length ? <div className="preview-grant-list">{grants.map((grant) => {
      const active = grant.active;
      const state = grant.revokedAt ? "İptal edildi" : active ? "Aktif" : "Süresi doldu";
      return <article className="preview-grant-card" key={grant.id}>
        <div><span className={`pill${active ? " pill--accent" : ""}`}>{state}</span><strong>{episodeSlug ? "Bölüm" : "Seri"} önizlemesi</strong><small>Oluşturuldu: {formatter.format(grant.createdAt)} · Bitiş: {formatter.format(grant.expiresAt)}</small></div>
        {active && (recentlyAuthenticated ? <form action="/api/admin/previews" method="post">
          <input type="hidden" name="action" value="revoke" />
          <input type="hidden" name="grant_id" value={grant.id} />
          {hiddenScopeFields({ seriesSlug, episodeSlug, returnTo })}
          <button className="button button--danger" type="submit">Bağlantıyı iptal et</button>
        </form> : <Link className="button button--ghost" href={reauthenticateHref(returnTo)}>İptal için şifreni doğrula</Link>)}
      </article>;
    })}</div> : <div className="empty-state"><strong>Henüz önizleme bağlantısı yok.</strong><p>Üstteki “Taslağı önizle” düğmesi yeni sekmede süreli bir bağlantı açar.</p></div>}
  </section>;
}
