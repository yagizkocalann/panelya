import { NextResponse } from "next/server";
import { assertSameOrigin, getCurrentUser } from "../../../lib/auth";
import { redirectTo } from "../../../lib/auth-http";
import { getDatabase } from "../../../lib/database";
import { consumeRateLimit, requestFingerprint } from "../../../lib/rate-limit";

function communityRedirect(request: Request, slug: string, state: string) {
  const url = new URL(`/${slug}`, request.url);
  url.searchParams.set("community", state);
  url.hash = "community";
  return NextResponse.redirect(url, 303);
}

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, "/login");
  if (!user.emailVerifiedAt) return redirectTo(request, "/account?error=Beğenmek%20için%20e-posta%20adresini%20doğrula.");
  const { id: reviewId } = await params;
  const form = await request.formData();
  const db = await getDatabase();
  const review = await db.prepare("SELECT user_id, series_slug, status FROM reviews WHERE id = ?")
    .bind(reviewId).first<{ user_id: string; series_slug: string; status: string }>();
  if (!review || review.status !== "published") return new Response("Yorum bulunamadı.", { status: 404 });
  const blocked = await db.prepare(`SELECT 1 AS found FROM user_blocks
    WHERE (blocker_user_id = ? AND blocked_user_id = ?)
       OR (blocker_user_id = ? AND blocked_user_id = ?) LIMIT 1`)
    .bind(user.id, review.user_id, review.user_id, user.id).first<{ found: number }>();
  if (blocked) return communityRedirect(request, review.series_slug, "interaction-blocked");
  const allowed = await consumeRateLimit("review-like", await requestFingerprint(request, user.id), 120, 60 * 60 * 1000);
  if (!allowed) return communityRedirect(request, review.series_slug, "like-rate-limited");
  if (form.get("action") === "unlike") {
    await db.prepare("DELETE FROM review_likes WHERE review_id = ? AND user_id = ?").bind(reviewId, user.id).run();
    return communityRedirect(request, review.series_slug, "like-removed");
  }
  await db.prepare("INSERT OR IGNORE INTO review_likes (review_id, user_id, created_at) VALUES (?, ?, ?)")
    .bind(reviewId, user.id, Date.now()).run();
  return communityRedirect(request, review.series_slug, "liked");
}
