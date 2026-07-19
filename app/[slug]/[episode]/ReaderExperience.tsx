"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import type { Episode, Series } from "../../data/catalog";

type ReaderExperienceProps = {
  series: Pick<Series, "slug" | "title">;
  episode: Episode;
  previous?: Pick<Episode, "slug" | "number">;
  next?: Pick<Episode, "slug" | "number">;
  preview?: { token: string; episodeScoped?: boolean };
};

export function ReaderExperience({ series, episode, previous, next, preview }: ReaderExperienceProps) {
  const [light, setLight] = useState(false);
  const [autoScroll, setAutoScroll] = useState(false);
  const scrollTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const lastSyncedRef = useRef(-1);
  const pendingPercentRef = useRef(0);
  const syncTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (preview?.token) return;
    const key = `panelya:progress:${series.slug}:${episode.slug}`;
    const update = () => {
      const total = document.documentElement.scrollHeight - window.innerHeight;
      const percent = total > 0 ? Math.min(100, Math.round((window.scrollY / total) * 100)) : 0;
      document.documentElement.style.setProperty("--reader-progress", `${percent}%`);
      try {
        localStorage.setItem(key, String(percent));
        localStorage.setItem(`panelya:last:${series.slug}`, JSON.stringify({ episodeSlug: episode.slug, episodeNumber: episode.number, episodeTitle: episode.title, percent }));
      } catch {
        // Reading still works when browser storage is unavailable.
      }
      pendingPercentRef.current = percent;
      if (!syncTimerRef.current && (Math.abs(percent - lastSyncedRef.current) >= 10 || percent === 100)) {
        syncTimerRef.current = setTimeout(() => {
          const nextPercent = pendingPercentRef.current;
          lastSyncedRef.current = nextPercent;
          syncTimerRef.current = null;
          void fetch("/api/progress", {
            method: "POST",
            credentials: "same-origin",
            headers: { "content-type": "application/json" },
            body: JSON.stringify({ seriesSlug: series.slug, episodeSlug: episode.slug, percent: nextPercent }),
            keepalive: true,
          });
        }, 650);
      }
    };
    window.addEventListener("scroll", update, { passive: true });
    return () => {
      window.removeEventListener("scroll", update);
      if (syncTimerRef.current) clearTimeout(syncTimerRef.current);
    };
  }, [episode.number, episode.slug, episode.title, preview?.token, series.slug]);

  useEffect(() => {
    if (!autoScroll) {
      if (scrollTimerRef.current) clearInterval(scrollTimerRef.current);
      return;
    }
    scrollTimerRef.current = setInterval(() => window.scrollBy(0, 1), 20);
    return () => { if (scrollTimerRef.current) clearInterval(scrollTimerRef.current); };
  }, [autoScroll]);

  const previewRoot = preview ? `/preview/${encodeURIComponent(preview.token)}` : null;
  const seriesHref = previewRoot ? `${previewRoot}${preview?.episodeScoped ? "?index=1" : ""}` : `/${series.slug}`;
  const episodeHref = (slug: string) => previewRoot ? `${previewRoot}?episode=${encodeURIComponent(slug)}` : `/${series.slug}/${slug}`;

  return (
    <div className={`reader${light ? " reader--light" : ""}`}>
      {preview && <div className="preview-ribbon" role="status">Taslak önizleme · yayınlanmadı · bağlantı 30 dakika geçerli</div>}
      <div className="reader-progress" aria-hidden="true"><span /></div>
      <header className="reader-header">
        <Link className="reader-back" href={seriesHref} aria-label={`${series.title} seri sayfasına dön`}>← <span>{series.title}</span></Link>
        <strong>Bölüm {episode.number}: {episode.title}</strong>
        <div className="reader-tools">
          <button type="button" className={autoScroll ? "is-active" : ""} onClick={() => setAutoScroll((value) => !value)} aria-pressed={autoScroll} aria-label="Otomatik kaydırmayı aç veya kapat">{autoScroll ? "■" : "▶"}</button>
          <button type="button" onClick={() => setLight((value) => !value)} aria-pressed={light} aria-label="Okuyucu temasını değiştir">{light ? "☾" : "☀"}</button>
        </div>
      </header>

      <main id="main-content" className="reader-main">
        <article className="webtoon-canvas" aria-label={`${series.title}, bölüm ${episode.number}: ${episode.title}`}>
          <div className={`story-title-panel story-panel--${episode.panels[0]?.tone ?? "blue"}`}>
            <span>Panelya Originals sunar</span><h1>{series.title}</h1><p>Bölüm {episode.number} · {episode.title}</p>
          </div>
          {episode.panels.map((panel, index) => (
            panel.image ? (
              <section key={panel.id} className="story-image-panel" aria-label={panel.scene}>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={panel.image.src} alt={panel.image.alt} width={panel.image.width} height={panel.image.height} loading={index === 0 ? "eager" : "lazy"} />
                {(panel.caption || panel.dialogue) && <div className="story-image-lettering" aria-label="Panel metni">
                  {panel.caption && <p className="story-image-caption">{panel.caption}</p>}
                  {panel.dialogue && <p className={`story-image-dialogue story-image-dialogue--${panel.align ?? (index % 2 ? "left" : "right")}`}>{panel.dialogue}</p>}
                </div>}
              </section>
            ) : (
              <section key={panel.id} className={`story-panel story-panel--${panel.tone} story-panel--${index % 3}`} aria-label={panel.scene}>
                <div className="panel-sky" aria-hidden="true"><i /><i /><i /></div>
                <div className={`panel-character panel-character--${panel.align ?? (index % 2 ? "left" : "right")}`} aria-hidden="true"><span /><b /><i /></div>
                {panel.caption && <p className="panel-caption">{panel.caption}</p>}
                {panel.dialogue && <p className={`speech speech--${panel.align ?? "left"}`}>{panel.dialogue}</p>}
                <span className="panel-index" aria-hidden="true">{String(index + 1).padStart(2, "0")}</span>
              </section>
            )
          ))}
          <div className="story-end"><span>Devam edecek</span><h2>Bu bölüm burada bitti.</h2><p>{preview ? "Bu bir taslak önizlemedir; okuma ilerlemesi kaydedilmez." : "İlerleme cihazda; giriş yaptıysan hesabında da otomatik kaydedildi."}</p></div>
        </article>

        <nav className="reader-end-nav" aria-label="Bölüm geçişleri">
          {previous ? <Link href={episodeHref(previous.slug)}>← Bölüm {previous.number}</Link> : <span />}
          <Link href={seriesHref}>Bölüm listesi</Link>
          {next ? <Link href={episodeHref(next.slug)}>Bölüm {next.number} →</Link> : <span />}
        </nav>
      </main>

      <nav className="reader-dock" aria-label="Hızlı bölüm geçişleri">
        {previous ? <Link href={episodeHref(previous.slug)}>← <span>Önceki</span></Link> : <span className="reader-dock__spacer" aria-hidden="true" />}
        <Link className="reader-dock__chapter" href={seriesHref}>Bölüm {episode.number}⌃</Link>
        {next ? <Link href={episodeHref(next.slug)}><span>Sonraki</span> →</Link> : <span className="reader-dock__spacer" aria-hidden="true" />}
      </nav>
    </div>
  );
}
