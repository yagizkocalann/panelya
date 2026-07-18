import type { PublicationStatus, StudioEpisode, StudioSeries } from "../../lib/content-repository";

const publicationLabels: Record<PublicationStatus, string> = { draft: "Taslak", published: "Yayında", archived: "Arşiv" };

export function SeriesForm({ series }: { series?: StudioSeries }) {
  return <form className="studio-editor" action="/api/admin/content/series" method="post">
    <input type="hidden" name="mode" value={series ? "update" : "create"} />
    {series && <input type="hidden" name="original_slug" value={series.slug} />}
    <section className="studio-editor__section"><header><div><p className="section-kicker">Temel bilgiler</p><h2>Seri kimliği</h2></div><span>Zorunlu alanlar</span></header>
      <div className="studio-form-grid">
        <label>Slug<input name="slug" defaultValue={series?.slug ?? ""} pattern="[a-z0-9]+(?:-[a-z0-9]+)*" maxLength={80} required readOnly={Boolean(series)} /><small>URL için küçük harf, rakam ve tire. Oluşturulduktan sonra değişmez.</small></label>
        <label>Seri adı<input name="title" defaultValue={series?.title ?? ""} minLength={2} maxLength={100} required /></label>
        <label className="span-2">Kısa kanca<input name="eyebrow" defaultValue={series?.eyebrow ?? ""} minLength={4} maxLength={160} required /></label>
        <label>Üretici<input name="creator" defaultValue={series?.creator ?? "Panelya Originals"} minLength={2} maxLength={100} required /></label>
        <label>Türler<input name="genres" defaultValue={series?.genres.join(", ") ?? ""} placeholder="Dram, Romantizm" required /><small>Virgülle ayır; en fazla 8 tür.</small></label>
      </div>
    </section>
    <section className="studio-editor__section"><header><div><p className="section-kicker">Tanıtım</p><h2>Okuyucu metinleri</h2></div></header>
      <div className="studio-form-grid">
        <label className="span-2">Kart özeti<textarea name="description" defaultValue={series?.description ?? ""} minLength={10} maxLength={300} rows={3} required /></label>
        <label className="span-2">Seri açıklaması<textarea name="long_description" defaultValue={series?.longDescription ?? ""} minLength={10} maxLength={2000} rows={7} required /></label>
      </div>
    </section>
    <section className="studio-editor__section"><header><div><p className="section-kicker">Sunum ve yayın</p><h2>Katalog ayarları</h2></div></header>
      <div className="studio-form-grid studio-form-grid--three">
        <label>Hikâye durumu<select name="story_status" defaultValue={series?.status === "Tamamlandı" ? "completed" : "ongoing"}><option value="ongoing">Devam ediyor</option><option value="completed">Tamamlandı</option></select></label>
        <label>Renk tonu<select name="tone" defaultValue={series?.tone ?? "coral"}><option value="coral">Mercan</option><option value="mint">Mint</option><option value="violet">Mor</option><option value="blue">Mavi</option><option value="amber">Kehribar</option><option value="rose">Gül</option></select></label>
        <label>Yayın durumu<select name="publication_status" defaultValue={series?.publicationStatus ?? "draft"}>{Object.entries(publicationLabels).map(([value, label]) => <option value={value} key={value}>{label}</option>)}</select></label>
        <label>Güncellik etiketi<input name="updated_label" defaultValue={series?.updatedAt ?? "Bugün"} maxLength={60} /></label>
        <label>Takipçi etiketi<input name="followers" defaultValue={series?.followers ?? "Yeni"} maxLength={30} /></label>
        <label>Kapak konumu<input name="cover_position" defaultValue={series?.coverPosition ?? "center"} maxLength={50} placeholder="50% 50%" /></label>
        <label className="span-3">Kapak görsel yolu<input name="cover_image" defaultValue={series?.coverImage ?? ""} maxLength={500} placeholder="/images/kapak.webp" /></label>
      </div>
      <div className="studio-checks"><label><input type="checkbox" name="is_new" value="yes" defaultChecked={series?.isNew ?? true} /> Yeni seri bölümünde göster</label><label><input type="checkbox" name="is_featured" value="yes" defaultChecked={series?.isFeatured ?? false} /> Ana sayfada öne çıkar</label></div>
      {!series && <p className="studio-inline-note">Yeni seri güvenlik için daima taslak oluşturulur. Bir bölüm yayınladıktan sonra seri düzenleme ekranından yayına alınabilir.</p>}
    </section>
    <div className="studio-editor__actions"><button className="button button--primary" type="submit">{series ? "Değişiklikleri kaydet" : "Taslak seriyi oluştur"}</button></div>
  </form>;
}

export function EpisodeForm({ series, episode }: { series: StudioSeries; episode?: StudioEpisode }) {
  const editablePanel = !episode || (episode.panels.length === 1 && !episode.panels[0]?.image);
  const panel = editablePanel ? episode?.panels[0] : undefined;
  return <form className="studio-editor" action="/api/admin/content/episodes" method="post">
    <input type="hidden" name="mode" value={episode ? "update" : "create"} />
    <input type="hidden" name="series_slug" value={series.slug} />
    {episode && <input type="hidden" name="original_slug" value={episode.slug} />}
    <section className="studio-editor__section"><header><div><p className="section-kicker">Bölüm bilgisi</p><h2>{episode ? "Bölümü düzenle" : "Yeni bölüm"}</h2></div><span>{series.title}</span></header>
      <div className="studio-form-grid studio-form-grid--three">
        <label>Slug<input name="slug" defaultValue={episode?.slug ?? ""} pattern="[a-z0-9]+(?:-[a-z0-9]+)*" maxLength={80} required /></label>
        <label>Bölüm numarası<input name="number" type="number" min={0} max={10000} step={1} defaultValue={episode?.number ?? series.episodes.length + 1} required /></label>
        <label>Yayın durumu<select name="publication_status" defaultValue={episode?.publicationStatus ?? "draft"}>{Object.entries(publicationLabels).map(([value, label]) => <option value={value} key={value}>{label}</option>)}</select></label>
        <label className="span-2">Bölüm adı<input name="title" defaultValue={episode?.title ?? ""} minLength={2} maxLength={120} required /></label>
        <label>Okuma süresi<input name="read_time" defaultValue={episode?.readTime ?? "5 dk"} maxLength={30} /></label>
        <label className="span-3">Yayın etiketi<input name="published_label" defaultValue={episode?.publishedAt ?? new Intl.DateTimeFormat("tr-TR", { dateStyle: "long" }).format(new Date())} maxLength={80} /></label>
      </div>
    </section>
    {editablePanel ? <section className="studio-editor__section"><header><div><p className="section-kicker">Yerel panel</p><h2>İlk anlatı paneli</h2></div><span>Medya yükleme öncesi</span></header>
      <div className="studio-form-grid">
        <label className="span-2">Sahne açıklaması<textarea name="panel_scene" defaultValue={panel?.scene ?? ""} minLength={4} maxLength={1000} rows={5} required /></label>
        <label>Panel tonu<select name="panel_tone" defaultValue={panel?.tone ?? series.tone}><option value="coral">Mercan</option><option value="mint">Mint</option><option value="violet">Mor</option><option value="blue">Mavi</option><option value="amber">Kehribar</option><option value="rose">Gül</option></select></label>
        <label>Hizalama<select name="panel_align" defaultValue={panel?.align ?? "left"}><option value="left">Sol</option><option value="right">Sağ</option></select></label>
        <label className="span-2">Anlatıcı metni<input name="panel_caption" defaultValue={panel?.caption ?? ""} maxLength={500} /></label>
        <label className="span-2">Diyalog<input name="panel_dialogue" defaultValue={panel?.dialogue ?? ""} maxLength={500} /></label>
      </div>
    </section> : <section className="studio-editor__section"><header><div><p className="section-kicker">Panel manifesti</p><h2>{episode?.panels.length} panel korunuyor</h2></div></header><p className="studio-inline-note">Bu bölüm çok panelli veya görsel tabanlı olduğu için bu aşamada yalnızca bölüm bilgileri düzenlenebilir. Panel sıralama ve medya düzenleme R2 hattında açılacak.</p></section>}
    <div className="studio-editor__actions"><button className="button button--primary" type="submit">{episode ? "Bölümü kaydet" : "Bölümü oluştur"}</button></div>
  </form>;
}
