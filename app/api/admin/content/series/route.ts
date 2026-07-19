import { assertSameOrigin, getCurrentUser } from "../../../../lib/auth";
import { createContentSeries, getStudioSeries, updateContentSeries, type PublicationStatus, type SeriesInput } from "../../../../lib/content-repository";
import { redirectTo } from "../../../../lib/auth-http";
import { writeAudit } from "../../../../lib/database";
import { assessSeriesPublishing } from "../../../../lib/publishing-readiness";
import { isStudioRequest } from "../../../../lib/site-origins";

const tones = new Set(["coral", "mint", "violet", "blue", "amber", "rose"]);
const publicationStatuses = new Set<PublicationStatus>(["draft", "published", "archived"]);
const slugPattern = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

function text(form: FormData, name: string, max: number) {
  return String(form.get(name) ?? "").trim().slice(0, max);
}

function parseInput(form: FormData): SeriesInput | null {
  const slug = text(form, "slug", 80);
  const title = text(form, "title", 100);
  const eyebrow = text(form, "eyebrow", 160);
  const creator = text(form, "creator", 100);
  const description = text(form, "description", 300);
  const longDescription = text(form, "long_description", 2000);
  const genres = text(form, "genres", 300).split(",").map((item) => item.trim()).filter(Boolean).slice(0, 8);
  const toneValue = text(form, "tone", 20);
  const publicationValue = text(form, "publication_status", 20) as PublicationStatus;
  if (!slugPattern.test(slug) || title.length < 2 || eyebrow.length < 4 || creator.length < 2 || description.length < 10 || longDescription.length < 10 || !genres.length || !tones.has(toneValue) || !publicationStatuses.has(publicationValue)) return null;
  return {
    slug,
    title,
    eyebrow,
    creator,
    description,
    longDescription,
    status: form.get("story_status") === "completed" ? "Tamamlandı" : "Devam Ediyor",
    genres,
    tone: toneValue as SeriesInput["tone"],
    updatedAt: text(form, "updated_label", 60) || "Bugün",
    followers: text(form, "followers", 30) || "Yeni",
    isNew: form.get("is_new") === "yes",
    coverImage: text(form, "cover_image", 500) || undefined,
    coverPosition: text(form, "cover_position", 50) || undefined,
    publicationStatus: publicationValue,
    isFeatured: form.get("is_featured") === "yes" && publicationValue === "published",
  };
}

export async function POST(request: Request) {
  if (!isStudioRequest(request)) return new Response("Not found", { status: 404 });
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, "/login?return_to=/content");
  if (user.role !== "admin") return new Response("Yetkisiz.", { status: 403 });
  const form = await request.formData();
  const mode = form.get("mode") === "update" ? "update" : "create";
  const originalSlug = text(form, "original_slug", 80);
  const input = parseInput(form);
  if (!input) {
    const path = mode === "create" ? "/content/new" : `/content/${originalSlug}`;
    return redirectTo(request, `${path}?error=Alanları%20kontrol%20et.`);
  }
  try {
    if (mode === "create") {
      input.publicationStatus = "draft";
      input.isFeatured = false;
      await createContentSeries(input);
      await writeAudit(user.id, "content.series_created", { seriesSlug: input.slug });
    } else {
      const current = await getStudioSeries(originalSlug);
      if (!current) return redirectTo(request, "/content?error=Seri%20bulunamadı.");
      input.slug = originalSlug;
      if (input.publicationStatus === "published") {
        const readiness = assessSeriesPublishing({ ...input, episodes: current.episodes });
        if (!readiness.ready) {
          return redirectTo(request, `/content/${originalSlug}?error=${encodeURIComponent(`Yayın engellendi: ${readiness.blocking.map((check) => check.label).join(", ")}.`)}`);
        }
        if (current.publicationStatus !== "published" && form.get("publish_confirmed") !== "yes") {
          return redirectTo(request, `/content/${originalSlug}?error=${encodeURIComponent("Public yayın için doğrulama özetini onayla.")}`);
        }
      }
      await updateContentSeries(originalSlug, input);
      await writeAudit(user.id, "content.series_updated", { seriesSlug: originalSlug, publicationStatus: input.publicationStatus, previousStatus: current.publicationStatus });
    }
  } catch {
    const path = mode === "create" ? "/content/new" : `/content/${originalSlug}`;
    return redirectTo(request, `${path}?error=Slug%20veya%20alanlardan%20biri%20başka%20bir%20kayıtla%20çakışıyor.`);
  }
  const destination = mode === "create" ? `/content/${input.slug}?created=1` : `/content/${originalSlug}?saved=1`;
  return redirectTo(request, destination);
}
