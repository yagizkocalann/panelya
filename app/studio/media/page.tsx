import Link from "next/link";
import Image from "next/image";
import { redirect } from "next/navigation";
import { SiteHeader } from "../../components/SiteHeader";
import { getCurrentUser } from "../../lib/auth";
import { listStudioSeries } from "../../lib/content-repository";
import { listMediaAssets } from "../../lib/media/repository";
import { publicSiteUrlForCurrentRequest } from "../../lib/server-site-origins";

export const dynamic = "force-dynamic";
function formatBytes(value: number) { return value < 1024 * 1024 ? `${Math.ceil(value / 1024)} KB` : `${(value / (1024 * 1024)).toFixed(1)} MB`; }

export default async function StudioMediaPage({ searchParams }: { searchParams: Promise<{ error?: string; uploaded?: string; restored?: string }> }) {
  const user = await getCurrentUser();
  if (!user) redirect("/login?return_to=/media");
  if (user.role !== "admin") redirect("/account?error=Studio%20yalnızca%20yönetici%20hesaplarına%20açık.");
  const [series, assets, publicHome, query] = await Promise.all([listStudioSeries(), listMediaAssets(), publicSiteUrlForCurrentRequest("/"), searchParams]);
  const uploaded = query.uploaded ? assets.find((asset) => asset.id === query.uploaded) : undefined;
  return <div className="site-shell studio-shell"><SiteHeader compact homeHref={publicHome} /><main id="main-content" className="studio-main wrap">
    <div className="studio-top"><div><p className="section-kicker">Medya</p><h1>Kapak ve paneller</h1><p>Özgün görselleri doğrula, R2 depolamaya yükle ve ilgili seri ya da bölüme bağla.</p></div><div className="studio-top__actions"><Link className="button button--ghost" href="/">← Studio</Link><Link className="button button--ghost" href="/content">İçeriğe git</Link></div></div>
    <aside className="studio-notice"><strong>Yükleme sınırı:</strong> JPEG, PNG veya WebP kabul edilir. Kapak en fazla 8 MB ve en az 320 × 400 px; panel en fazla 12 MB ve en az 320 × 240 px olmalıdır. Dosya imzası, MIME türü, boyut ve piksel sınırları sunucuda tekrar doğrulanır.</aside>
    {query.error && <p className="form-message form-message--error" role="alert">{query.error}</p>}
    {uploaded && <p className="form-message form-message--success" role="status">{uploaded.kind === "cover" ? "Kapak" : "Panel"} yüklendi ve ilgili içeriğe bağlandı.</p>}
    {query.restored && <p className="form-message form-message--success" role="status">Seçilen kapak geçmişten geri yüklendi.</p>}
    <section className="studio-editor" aria-labelledby="media-upload-title"><div className="studio-editor__section"><header><div><p className="section-kicker">R2 medya nesnesi</p><h2 id="media-upload-title">Yeni dosya yükle</h2></div><span>Admin işlemi</span></header>
      {!series.length ? <p className="studio-inline-note">Önce bir seri oluşturmalısın. <Link href="/content/new">Yeni seri oluştur →</Link></p> : <form className="studio-form-grid" action="/api/admin/media" method="post" encType="multipart/form-data">
        <label>Varlık türü<select name="kind" defaultValue="cover"><option value="cover">Seri kapağı</option><option value="panel">Bölüm paneli</option></select><small>Panel seçildiğinde aşağıdaki bölüm zorunludur.</small></label>
        <label>Seri<select name="series_slug" required defaultValue=""><option value="" disabled>Seri seç</option>{series.map((item) => <option key={item.slug} value={item.slug}>{item.title}</option>)}</select></label>
        <label className="span-2">Bölüm (yalnız panel için)<select name="episode_slug" defaultValue=""><option value="">Kapak için boş bırak</option>{series.flatMap((item) => item.episodes.map((episode) => <option key={`${item.slug}-${episode.slug}`} value={episode.slug}>{item.title} · Bölüm {episode.number}: {episode.title}</option>))}</select><small>Seçilen bölüm, seçilen seriyle eşleşmelidir.</small></label>
        <label className="span-2">Görsel dosyası<input name="file" type="file" accept="image/jpeg,image/png,image/webp" required /><small>Yükleme sonrası dosya adı URL’ye taşınmaz; hashli ve değişmez bir R2 anahtarı kullanılır.</small></label>
        <div className="studio-editor__actions span-2"><button className="button button--primary" type="submit">Dosyayı doğrula ve yükle</button></div>
      </form>}
    </div></section>
    <section className="studio-section" aria-labelledby="media-library-title"><div className="section-heading"><div><p className="section-kicker">Envanter</p><h2 id="media-library-title">Yüklenen dosyalar</h2></div><span className="sort-note">{assets.length} varlık</span></div>
      {assets.length ? <div className="media-library">{assets.map((asset) => {
        const owner = series.find((item) => item.slug === asset.seriesSlug);
        const activeCover = asset.kind === "cover" && owner?.coverImage === `/api/media/${asset.id}`;
        return <article key={asset.id}><a className="media-library__preview" href={`/api/admin/media/${asset.id}`} target="_blank" rel="noreferrer" aria-label={`${asset.originalFilename} dosyasını yeni sekmede aç`}><Image src={`/api/admin/media/${asset.id}`} alt="" width={asset.width} height={asset.height} loading="lazy" unoptimized /></a><div><div className="inventory-status"><span className="pill pill--accent">{asset.kind === "cover" ? "Kapak" : "Panel"}</span><span className="pill">{asset.mimeType.replace("image/", "").toUpperCase()}</span>{activeCover && <span className="pill">Aktif</span>}</div><strong>{asset.originalFilename}</strong><small>{asset.seriesSlug}{asset.episodeSlug ? ` · ${asset.episodeSlug}` : ""}</small><small>{asset.width} × {asset.height} px · {formatBytes(asset.byteSize)}</small></div><div className="media-library__actions"><a className="inline-link" href={`/api/admin/media/${asset.id}`} target="_blank" rel="noreferrer">Önizle →</a>{asset.kind === "cover" && !activeCover && <form action="/api/admin/media/manage" method="post"><input type="hidden" name="action" value="cover_restore" /><input type="hidden" name="media_id" value={asset.id} /><input type="hidden" name="series_slug" value={asset.seriesSlug} /><input type="hidden" name="return_to" value="/media" /><button className="button button--ghost" type="submit">Kapak yap</button></form>}</div></article>;
      })}</div> : <div className="empty-state"><strong>Henüz medya yok.</strong><p>İlk kapak ya da paneli bu formdan yüklediğinde burada görünür.</p></div>}
    </section>
  </main></div>;
}
