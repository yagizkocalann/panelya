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

export function PreviewCreateForm({ seriesSlug, episodeSlug, returnTo }: PreviewScope) {
  return <form action="/api/admin/previews" method="post" target="_blank">
    <input type="hidden" name="action" value="create" />
    {hiddenScopeFields({ seriesSlug, episodeSlug, returnTo })}
    <button className="button button--primary" type="submit">Taslağı önizle ↗</button>
  </form>;
}

export function PreviewAccessPanel({ grants, seriesSlug, episodeSlug, returnTo }: PreviewScope & { grants: PreviewGrant[] }) {
  const formatter = new Intl.DateTimeFormat("tr-TR", { dateStyle: "short", timeStyle: "short", timeZone: "Europe/Istanbul" });

  return <section className="studio-section preview-access" aria-labelledby="preview-access-title">
    <div className="section-heading"><div><p className="section-kicker">Güvenli paylaşım</p><h2 id="preview-access-title">Taslak önizleme bağlantıları</h2></div><span className="sort-note">30 dakika geçerli</span></div>
    <p className="studio-inline-note">Her bağlantı yalnız bu {episodeSlug ? "bölümü" : "seriyi"} açar. Ham anahtar saklanmaz; süresi dolmadan Studio üzerinden iptal edilebilir.</p>
    {grants.length ? <div className="preview-grant-list">{grants.map((grant) => {
      const active = grant.active;
      const state = grant.revokedAt ? "İptal edildi" : active ? "Aktif" : "Süresi doldu";
      return <article className="preview-grant-card" key={grant.id}>
        <div><span className={`pill${active ? " pill--accent" : ""}`}>{state}</span><strong>{episodeSlug ? "Bölüm" : "Seri"} önizlemesi</strong><small>Oluşturuldu: {formatter.format(grant.createdAt)} · Bitiş: {formatter.format(grant.expiresAt)}</small></div>
        {active && <form action="/api/admin/previews" method="post">
          <input type="hidden" name="action" value="revoke" />
          <input type="hidden" name="grant_id" value={grant.id} />
          {hiddenScopeFields({ seriesSlug, episodeSlug, returnTo })}
          <button className="button button--danger" type="submit">Bağlantıyı iptal et</button>
        </form>}
      </article>;
    })}</div> : <div className="empty-state"><strong>Henüz önizleme bağlantısı yok.</strong><p>Üstteki “Taslağı önizle” düğmesi yeni sekmede süreli bir bağlantı açar.</p></div>}
  </section>;
}
