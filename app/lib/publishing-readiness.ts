import type { StoryPanel } from "../data/catalog";
import type { PublicationStatus, StudioEpisode, StudioSeries } from "./content-repository";

export type PublishingCheck = {
  id: string;
  label: string;
  detail: string;
  status: "ready" | "warning" | "blocking";
};

export type PublishingReadiness = {
  checks: PublishingCheck[];
  blocking: PublishingCheck[];
  warnings: PublishingCheck[];
  ready: boolean;
};

function summarize(checks: PublishingCheck[]): PublishingReadiness {
  const blocking = checks.filter((check) => check.status === "blocking");
  const warnings = checks.filter((check) => check.status === "warning");
  return { checks, blocking, warnings, ready: blocking.length === 0 };
}

function panelHasAccessibilityIssue(panel: StoryPanel) {
  if (!panel.image) return !panel.scene.trim();
  return !panel.image.alt.trim()
    || !Number.isFinite(panel.image.width)
    || panel.image.width <= 0
    || !Number.isFinite(panel.image.height)
    || panel.image.height <= 0;
}

type SeriesCandidate = Pick<StudioSeries, "title" | "description" | "longDescription" | "genres" | "coverImage"> & {
  episodes: Array<Pick<StudioEpisode, "publicationStatus" | "panels">>;
};

export function assessSeriesPublishing(series: SeriesCandidate): PublishingReadiness {
  const publishedEpisodes = series.episodes.filter((episode) => episode.publicationStatus === "published");
  const emptyPublishedEpisodes = publishedEpisodes.filter((episode) => episode.panels.length === 0).length;
  const invalidPublishedPanels = publishedEpisodes.flatMap((episode) => episode.panels).filter(panelHasAccessibilityIssue).length;
  return summarize([
    {
      id: "series-metadata",
      label: "Seri metadatası",
      detail: "Başlık, açıklamalar ve en az bir tür tamamlandı.",
      status: series.title.trim().length >= 2 && series.description.trim().length >= 10 && series.longDescription.trim().length >= 10 && series.genres.length > 0 ? "ready" : "blocking",
    },
    {
      id: "published-episode",
      label: "Yayındaki bölüm",
      detail: publishedEpisodes.length ? `${publishedEpisodes.length} bölüm yayında.` : "Seriyi görünür yapmak için önce en az bir bölümü yayınla.",
      status: publishedEpisodes.length ? "ready" : "blocking",
    },
    {
      id: "episode-panels",
      label: "Bölüm panel bütünlüğü",
      detail: emptyPublishedEpisodes || invalidPublishedPanels
        ? `${emptyPublishedEpisodes} yayındaki bölüm boş; ${invalidPublishedPanels} panelde boyut, alt metin veya sahne açıklaması eksik.`
        : "Yayındaki bölümlerin panel manifesti ve erişilebilirlik alanları uygun.",
      status: emptyPublishedEpisodes || invalidPublishedPanels ? "blocking" : "ready",
    },
    {
      id: "cover-image",
      label: "Kapak görseli",
      detail: series.coverImage ? "Katalog kapağı bağlı." : "Yayın engellenmez; katalog kalitesi için kapak eklenmesi önerilir.",
      status: series.coverImage ? "ready" : "warning",
    },
  ]);
}

type EpisodeCandidate = {
  title: string;
  publishedAt: string;
  readTime: string;
  panels: StoryPanel[];
  seriesPublicationStatus: PublicationStatus;
};

export function assessEpisodePublishing(episode: EpisodeCandidate): PublishingReadiness {
  const invalidImages = episode.panels.filter((panel) => panel.image && panelHasAccessibilityIssue(panel)).length;
  const emptyTextPanels = episode.panels.filter((panel) => !panel.image && !panel.scene.trim()).length;
  return summarize([
    {
      id: "episode-metadata",
      label: "Bölüm metadatası",
      detail: "Başlık, yayın etiketi ve okuma süresi tamamlandı.",
      status: episode.title.trim().length >= 2 && episode.publishedAt.trim().length > 0 && episode.readTime.trim().length > 0 ? "ready" : "blocking",
    },
    {
      id: "episode-panels",
      label: "Panel manifesti",
      detail: episode.panels.length ? `${episode.panels.length} panel bağlı.` : "Yayın için en az bir panel gerekir.",
      status: episode.panels.length ? "ready" : "blocking",
    },
    {
      id: "panel-accessibility",
      label: "Panel erişilebilirliği",
      detail: invalidImages || emptyTextPanels
        ? `${invalidImages} görsel panelde boyut/alt metin, ${emptyTextPanels} metin panelinde sahne açıklaması eksik.`
        : "Görsel boyutları, alt metinler ve sahne açıklamaları uygun.",
      status: invalidImages || emptyTextPanels ? "blocking" : "ready",
    },
    {
      id: "series-visibility",
      label: "Public görünürlük",
      detail: episode.seriesPublicationStatus === "published" ? "Seri yayında; bölüm yayınlanınca okuyucuya açılır." : "Bölüm yayınlanabilir ancak seri de yayınlanana kadar public görünmez.",
      status: episode.seriesPublicationStatus === "published" ? "ready" : "warning",
    },
  ]);
}
