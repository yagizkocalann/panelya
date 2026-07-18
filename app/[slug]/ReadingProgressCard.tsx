"use client";

import Link from "next/link";
import { useSyncExternalStore } from "react";

type SavedProgress = {
  episodeSlug: string;
  episodeNumber: number;
  episodeTitle: string;
  percent: number;
};

export function ReadingProgressCard({ seriesSlug, firstEpisodeSlug }: { seriesSlug: string; firstEpisodeSlug: string }) {
  const raw = useSyncExternalStore(
    () => () => undefined,
    () => {
      try { return localStorage.getItem(`panelya:last:${seriesSlug}`) ?? ""; }
      catch { return ""; }
    },
    () => "",
  );
  let saved: SavedProgress | null = null;
  try {
    const parsed = raw ? JSON.parse(raw) as Partial<SavedProgress> : null;
    if (parsed && typeof parsed.episodeSlug === "string" && typeof parsed.episodeNumber === "number" && typeof parsed.episodeTitle === "string" && typeof parsed.percent === "number") saved = parsed as SavedProgress;
  } catch {
    saved = null;
  }

  const href = `/${seriesSlug}/${saved?.episodeSlug ?? firstEpisodeSlug}`;
  return (
    <section className="progress-promo wrap" aria-label="Okuma ilerlemesi">
      <div className="progress-promo__icon" aria-hidden="true">↗</div>
      <div>
        <p className="section-kicker">Okuma durumu</p>
        <h2>{saved ? `Bölüm ${saved.episodeNumber}: ${saved.episodeTitle}` : "Kaldığın yer bu cihazda seni bekler."}</h2>
        <p>{saved ? `%${Math.max(1, saved.percent)} tamamlandı · Cihazında ve giriş yaptıysan hesabında saklanıyor.` : "Okuyucu ilerlemeni cihazında; giriş yaptıysan hesabında da otomatik kaydeder."}</p>
        {saved && <div className="saved-progress" aria-label={`Yüzde ${saved.percent} tamamlandı`}><span style={{ width: `${saved.percent}%` }} /></div>}
      </div>
      <Link className="inline-link" href={href}>{saved ? "Devam et →" : "Okumaya başla →"}</Link>
    </section>
  );
}
