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

function responsiveSrcSet(src: string) {
  if (!/^\/api\/(?:preview\/)?media\/[A-Za-z0-9-]+(?:\?.*)?$/.test(src)) return undefined;
  const separator = src.includes("?") ? "&" : "?";
  return [480, 768, 1200].map((width) => `${src}${separator}width=${width} ${width}w`).join(", ");
}

type PanelImage = NonNullable<Episode["panels"][number]["image"]>;

function ReaderPanelImage({ image, priority }: { image: PanelImage; priority: boolean }) {
  const [state, setState] = useState<"loading" | "loaded" | "error">("loading");
  const [attempt, setAttempt] = useState(0);
  const imageRef = useRef<HTMLImageElement | null>(null);
  const separator = image.src.includes("?") ? "&" : "?";
  const src = attempt ? `${image.src}${separator}retry=${attempt}` : image.src;

  useEffect(() => {
    const element = imageRef.current;
    if (element?.complete) setState(element.naturalWidth > 0 ? "loaded" : "error");
  }, [src]);

  return (
    <div className="reader-panel-media" style={{ aspectRatio: `${image.width} / ${image.height}` }} data-image-state={state}>
      {state === "loading" && <div className="reader-image-placeholder" aria-hidden="true"><span>Panel yükleniyor</span></div>}
      {state !== "error" && (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          key={src}
          ref={imageRef}
          src={src}
          srcSet={responsiveSrcSet(src)}
          sizes="(max-width: 760px) 100vw, 760px"
          alt={image.alt}
          width={image.width}
          height={image.height}
          loading={priority ? "eager" : "lazy"}
          fetchPriority={priority ? "high" : "auto"}
          decoding="async"
          onLoad={() => setState("loaded")}
          onError={() => setState("error")}
        />
      )}
      {state === "error" && (
        <div className="reader-image-fallback" role="img" aria-label={image.alt}>
          <strong>Panel görseli yüklenemedi.</strong>
          <p>{image.alt}</p>
          <button className="button button--ghost" type="button" onClick={() => { setState("loading"); setAttempt((value) => value + 1); }}>Tekrar dene</button>
        </div>
      )}
    </div>
  );
}

export function ReaderExperience({ series, episode, previous, next, preview }: ReaderExperienceProps) {
  const [light, setLight] = useState(false);
  const [autoScroll, setAutoScroll] = useState(false);
  const [reducedMotion, setReducedMotion] = useState(false);
  const [restoreAnnouncement, setRestoreAnnouncement] = useState("");
  const autoScrollFrameRef = useRef<number | null>(null);
  const autoScrollTimeRef = useRef<number | null>(null);
  const scrollFrameRef = useRef<number | null>(null);
  const lastSyncedRef = useRef(-1);
  const lastStoredPercentRef = useRef(-1);
  const pendingPercentRef = useRef(0);
  const syncTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (preview?.token) return;
    const key = `panelya:progress:${series.slug}:${episode.slug}`;
    let active = true;

    const syncProgress = (percent: number) => {
      lastSyncedRef.current = percent;
      void fetch("/api/progress", {
        method: "POST",
        credentials: "same-origin",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ seriesSlug: series.slug, episodeSlug: episode.slug, percent }),
        keepalive: true,
      }).catch(() => undefined);
    };

    const update = () => {
      scrollFrameRef.current = null;
      const total = document.documentElement.scrollHeight - window.innerHeight;
      const percent = total > 0 ? Math.min(100, Math.round((window.scrollY / total) * 100)) : 0;
      document.documentElement.style.setProperty("--reader-progress", `${percent}%`);
      if (percent !== lastStoredPercentRef.current) {
        try {
          localStorage.setItem(key, String(percent));
          localStorage.setItem(`panelya:last:${series.slug}`, JSON.stringify({ episodeSlug: episode.slug, episodeNumber: episode.number, episodeTitle: episode.title, percent }));
        } catch {
          // Reading still works when browser storage is unavailable.
        }
        lastStoredPercentRef.current = percent;
      }
      pendingPercentRef.current = percent;
      if (!syncTimerRef.current && (Math.abs(percent - lastSyncedRef.current) >= 10 || percent === 100)) {
        syncTimerRef.current = setTimeout(() => {
          const nextPercent = pendingPercentRef.current;
          syncTimerRef.current = null;
          syncProgress(nextPercent);
        }, 650);
      }
    };

    const scheduleUpdate = () => {
      if (scrollFrameRef.current === null) scrollFrameRef.current = window.requestAnimationFrame(update);
    };
    const flush = () => {
      if (syncTimerRef.current) {
        clearTimeout(syncTimerRef.current);
        syncTimerRef.current = null;
      }
      if (pendingPercentRef.current !== lastSyncedRef.current) syncProgress(pendingPercentRef.current);
    };
    const handleVisibility = () => { if (document.visibilityState === "hidden") flush(); };
    const restore = () => {
      if (!active) return;
      try {
        const savedPercent = Number(localStorage.getItem(key));
        if (!Number.isFinite(savedPercent) || savedPercent < 2 || savedPercent >= 100) return;
        const total = document.documentElement.scrollHeight - window.innerHeight;
        if (total <= 0) return;
        const percent = Math.round(savedPercent);
        window.scrollTo({ top: Math.round(total * (percent / 100)), behavior: "auto" });
        document.documentElement.style.setProperty("--reader-progress", `${percent}%`);
        pendingPercentRef.current = percent;
        lastSyncedRef.current = percent;
        lastStoredPercentRef.current = percent;
        setRestoreAnnouncement(`Okumaya yüzde ${percent} konumundan devam ediliyor.`);
      } catch {
        // Start from the beginning when browser storage is unavailable.
      }
    };
    let tracking = false;
    const startTracking = () => {
      if (!active || tracking) return;
      tracking = true;
      window.addEventListener("scroll", scheduleUpdate, { passive: true });
      window.addEventListener("pagehide", flush);
      document.addEventListener("visibilitychange", handleVisibility);
    };
    const restoreTimer = window.setTimeout(() => {
      restore();
      startTracking();
    }, 120);
    return () => {
      active = false;
      if (tracking) {
        window.removeEventListener("scroll", scheduleUpdate);
        window.removeEventListener("pagehide", flush);
        document.removeEventListener("visibilitychange", handleVisibility);
      }
      clearTimeout(restoreTimer);
      if (scrollFrameRef.current !== null) cancelAnimationFrame(scrollFrameRef.current);
      if (syncTimerRef.current) clearTimeout(syncTimerRef.current);
    };
  }, [episode.number, episode.slug, episode.title, preview?.token, series.slug]);

  useEffect(() => {
    const query = window.matchMedia("(prefers-reduced-motion: reduce)");
    const updatePreference = () => {
      setReducedMotion(query.matches);
      if (query.matches) setAutoScroll(false);
    };
    updatePreference();
    query.addEventListener("change", updatePreference);
    return () => query.removeEventListener("change", updatePreference);
  }, []);

  useEffect(() => {
    if (!autoScroll || reducedMotion) return;
    const tick = (time: number) => {
      if (autoScrollTimeRef.current !== null) window.scrollBy(0, Math.max(1, (time - autoScrollTimeRef.current) * 0.035));
      autoScrollTimeRef.current = time;
      autoScrollFrameRef.current = requestAnimationFrame(tick);
    };
    autoScrollFrameRef.current = requestAnimationFrame(tick);
    return () => {
      if (autoScrollFrameRef.current !== null) cancelAnimationFrame(autoScrollFrameRef.current);
      autoScrollFrameRef.current = null;
      autoScrollTimeRef.current = null;
    };
  }, [autoScroll, reducedMotion]);

  const previewRoot = preview ? `/preview/${encodeURIComponent(preview.token)}` : null;
  const seriesHref = previewRoot ? `${previewRoot}${preview?.episodeScoped ? "?index=1" : ""}` : `/${series.slug}`;
  const episodeHref = (slug: string) => previewRoot ? `${previewRoot}?episode=${encodeURIComponent(slug)}` : `/${series.slug}/${slug}`;
  const firstImageIndex = episode.panels.findIndex((panel) => Boolean(panel.image));

  return (
    <div className={`reader${light ? " reader--light" : ""}`}>
      {preview && <div className="preview-ribbon" role="status">Taslak önizleme · yayınlanmadı · bağlantı 30 dakika geçerli</div>}
      <p className="sr-only" aria-live="polite">{restoreAnnouncement}</p>
      <div className="reader-progress" aria-hidden="true"><span /></div>
      <header className="reader-header">
        <Link className="reader-back" href={seriesHref} aria-label={`${series.title} seri sayfasına dön`}>← <span>{series.title}</span></Link>
        <strong>Bölüm {episode.number}: {episode.title}</strong>
        <div className="reader-tools">
          <button type="button" className={autoScroll ? "is-active" : ""} onClick={() => setAutoScroll((value) => !value)} aria-pressed={autoScroll} aria-label={reducedMotion ? "Otomatik kaydırma azaltılmış hareket tercihinde kullanılamaz" : "Otomatik kaydırmayı aç veya kapat"} disabled={reducedMotion}>{autoScroll ? "■" : "▶"}</button>
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
                <ReaderPanelImage image={panel.image} priority={index === firstImageIndex} />
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
