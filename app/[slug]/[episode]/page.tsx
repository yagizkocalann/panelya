import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { getAdjacentEpisodes, getEpisode } from "../../data/catalog";
import { getPublishedSeries } from "../../lib/content-repository";
import { ReaderExperience } from "./ReaderExperience";

type EpisodePageProps = { params: Promise<{ slug: string; episode: string }> };

export async function generateMetadata({ params }: EpisodePageProps): Promise<Metadata> {
  const { slug, episode: episodeSlug } = await params;
  const series = await getPublishedSeries(slug);
  const episode = series ? getEpisode(series, episodeSlug) : undefined;
  if (!series || !episode) return { title: "Bölüm bulunamadı — Panelya" };
  return { title: `${series.title} · Bölüm ${episode.number}: ${episode.title} — Panelya`, robots: { index: false, follow: true } };
}

export default async function EpisodePage({ params }: EpisodePageProps) {
  const { slug, episode: episodeSlug } = await params;
  const series = await getPublishedSeries(slug);
  if (!series) notFound();
  const episode = getEpisode(series, episodeSlug);
  if (!episode) notFound();
  const adjacent = getAdjacentEpisodes(series, episode);
  return <ReaderExperience series={{ slug: series.slug, title: series.title }} episode={episode} previous={adjacent.previous} next={adjacent.next} />;
}
