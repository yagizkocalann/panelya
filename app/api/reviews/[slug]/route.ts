import { NextResponse } from "next/server";
import { getPublishedSeries } from "../../../lib/content-repository";
import { assertSameOrigin, getCurrentUser } from "../../../lib/auth";
import { redirectTo } from "../../../lib/auth-http";
import { getDatabase, writeAudit } from "../../../lib/database";
import { consumeRateLimit, requestFingerprint } from "../../../lib/rate-limit";

function communityRedirect(request: Request, slug: string, state: string) {
  const url = new URL(`/${slug}`, request.url);
  url.searchParams.set("community", state);
  url.hash = "community";
  return NextResponse.redirect(url, 303);
}

export async function POST(request: Request, { params }: { params: Promise<{ slug: string }> }) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const { slug } = await params;
  if (!(await getPublishedSeries(slug))) return new Response("Seri bulunamadı.", { status: 404 });
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, `/login?return_to=${encodeURIComponent(`/${slug}#community`)}`);
  if (!user.emailVerifiedAt) return redirectTo(request, "/account?error=Yorum%20yazmak%20için%20e-posta%20adresini%20doğrula.");
  const allowed = await consumeRateLimit("review-write", await requestFingerprint(request, user.id), 12, 60 * 60 * 1000);
  if (!allowed) return communityRedirect(request, slug, "rate-limited");
  const form = await request.formData();
  const db = await getDatabase();
  if (form.get("action") === "delete") {
    await db.prepare("DELETE FROM reviews WHERE user_id = ? AND series_slug = ?").bind(user.id, slug).run();
    await writeAudit(user.id, "review.deleted", { seriesSlug: slug });
    return communityRedirect(request, slug, "review-deleted");
  }
  const rating = Number(form.get("rating"));
  const comment = String(form.get("comment") ?? "").trim();
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) return communityRedirect(request, slug, "invalid-rating");
  if ((comment.length > 0 && comment.length < 10) || comment.length > 1000) return communityRedirect(request, slug, "invalid-comment");
  const now = Date.now();
  await db.prepare(`INSERT INTO reviews (id, user_id, series_slug, rating, comment, contains_spoiler, status, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, 'published', ?, ?)
    ON CONFLICT(user_id, series_slug) DO UPDATE SET
      rating = excluded.rating,
      comment = excluded.comment,
      contains_spoiler = excluded.contains_spoiler,
      status = CASE WHEN reviews.status = 'hidden' THEN 'hidden' ELSE 'published' END,
      updated_at = excluded.updated_at`)
    .bind(crypto.randomUUID(), user.id, slug, rating, comment || null, form.get("contains_spoiler") === "yes" ? 1 : 0, now, now).run();
  await writeAudit(user.id, "review.saved", { seriesSlug: slug, rating, containsSpoiler: form.get("contains_spoiler") === "yes" });
  return communityRedirect(request, slug, "review-saved");
}
