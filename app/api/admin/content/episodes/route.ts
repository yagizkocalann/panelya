import { assertSameOrigin, getCurrentUser } from "../../../../lib/auth";
import { createContentEpisode, getStudioSeries, updateContentEpisode, type EpisodeInput, type PublicationStatus } from "../../../../lib/content-repository";
import { redirectTo } from "../../../../lib/auth-http";
import { writeAudit } from "../../../../lib/database";
import { isStudioRequest, publicSiteOrigin } from "../../../../lib/site-origins";
import { dispatchNewEpisodeNotifications } from "../../../../lib/series-subscriptions";

const publicationStatuses = new Set<PublicationStatus>(["draft", "published", "archived"]);
const tones = new Set(["coral", "mint", "violet", "blue", "amber", "rose"]);
const slugPattern = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

function text(form: FormData, name: string, max: number) {
  return String(form.get(name) ?? "").trim().slice(0, max);
}

function parseInput(form: FormData): EpisodeInput | null {
  const seriesSlug = text(form, "series_slug", 80);
  const slug = text(form, "slug", 80);
  const title = text(form, "title", 120);
  const number = Number(form.get("number"));
  const publicationStatus = text(form, "publication_status", 20) as PublicationStatus;
  if (!slugPattern.test(seriesSlug) || !slugPattern.test(slug) || title.length < 2 || !Number.isInteger(number) || number < 0 || number > 10000 || !publicationStatuses.has(publicationStatus)) return null;
  const input: EpisodeInput = {
    seriesSlug,
    slug,
    number,
    title,
    publishedAt: text(form, "published_label", 80) || "Henüz yayınlanmadı",
    readTime: text(form, "read_time", 30) || "5 dk",
    publicationStatus,
  };
  if (form.has("panel_scene")) {
    const scene = text(form, "panel_scene", 1000);
    const tone = text(form, "panel_tone", 20);
    if (!scene || !tones.has(tone)) return null;
    input.panels = [{
      id: crypto.randomUUID(),
      scene,
      caption: text(form, "panel_caption", 500) || undefined,
      dialogue: text(form, "panel_dialogue", 500) || undefined,
      tone: tone as NonNullable<EpisodeInput["panels"]>[number]["tone"],
      align: form.get("panel_align") === "right" ? "right" : "left",
    }];
  }
  return input;
}

export async function POST(request: Request) {
  if (!isStudioRequest(request)) return new Response("Not found", { status: 404 });
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, "/login?return_to=/content");
  if (user.role !== "admin") return new Response("Yetkisiz.", { status: 403 });
  const form = await request.formData();
  const input = parseInput(form);
  const fallbackSeries = text(form, "series_slug", 80);
  if (!input) return redirectTo(request, `/content/${fallbackSeries}/episodes/new?error=Alanları%20kontrol%20et.`);
  const series = await getStudioSeries(input.seriesSlug);
  if (!series) return redirectTo(request, "/content?error=Seri%20bulunamadı.");
  const mode = form.get("mode") === "update" ? "update" : "create";
  const originalSlug = text(form, "original_slug", 80);
  const previousEpisode = mode === "update" ? series.episodes.find((episode) => episode.slug === originalSlug) : undefined;
  if (input.publicationStatus === "published" && !(input.panels?.length || (mode === "update" && series.episodes.find((episode) => episode.slug === originalSlug)?.panels.length))) {
    const path = mode === "create" ? `/content/${input.seriesSlug}/episodes/new` : `/content/${input.seriesSlug}/episodes/${originalSlug}`;
    return redirectTo(request, `${path}?error=Yayınlanan%20bölümde%20en%20az%20bir%20panel%20olmalı.`);
  }
  try {
    if (mode === "create") {
      await createContentEpisode(input);
      await writeAudit(user.id, "content.episode_created", { seriesSlug: input.seriesSlug, episodeSlug: input.slug });
    } else {
      await updateContentEpisode(input.seriesSlug, originalSlug, input);
      await writeAudit(user.id, "content.episode_updated", { seriesSlug: input.seriesSlug, episodeSlug: input.slug, publicationStatus: input.publicationStatus });
    }
  } catch {
    const path = mode === "create" ? `/content/${input.seriesSlug}/episodes/new` : `/content/${input.seriesSlug}/episodes/${originalSlug}`;
    return redirectTo(request, `${path}?error=Slug%20veya%20bölüm%20numarası%20başka%20bir%20kayıtla%20çakışıyor.`);
  }
  const shouldNotify = series.publicationStatus === "published"
    && input.publicationStatus === "published"
    && (mode === "create" || previousEpisode?.publicationStatus !== "published");
  if (!shouldNotify) return redirectTo(request, `/content/${input.seriesSlug}/episodes/${input.slug}?saved=1`);

  try {
    const result = await dispatchNewEpisodeNotifications({
      seriesSlug: input.seriesSlug,
      seriesTitle: series.title,
      episodeSlug: input.slug,
      episodeTitle: input.title,
      episodeUrl: new URL(`/${input.seriesSlug}/${input.slug}`, `${publicSiteOrigin(request)}/`).toString(),
    });
    await writeAudit(user.id, "content.episode_notifications_dispatched", {
      seriesSlug: input.seriesSlug,
      episodeSlug: input.slug,
      subscriberCount: result.subscribers,
      queuedCount: result.queued,
      failedCount: result.failed,
    });
    const notificationState = result.failed ? "partial" : "queued";
    return redirectTo(request, `/content/${input.seriesSlug}/episodes/${input.slug}?saved=1&notifications=${notificationState}&count=${result.queued}`);
  } catch {
    await writeAudit(user.id, "content.episode_notifications_failed", { seriesSlug: input.seriesSlug, episodeSlug: input.slug });
    return redirectTo(request, `/content/${input.seriesSlug}/episodes/${input.slug}?saved=1&notifications=failed`);
  }
}
