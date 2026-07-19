import { NextResponse } from "next/server";
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

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, "/login");
  if (!user.emailVerifiedAt) return redirectTo(request, "/account?error=Yanıt%20yazmak%20için%20e-posta%20adresini%20doğrula.");
  const { id: reviewId } = await params;
  const form = await request.formData();
  const db = await getDatabase();
  const review = await db.prepare("SELECT user_id, series_slug, status FROM reviews WHERE id = ?")
    .bind(reviewId).first<{ user_id: string; series_slug: string; status: string }>();
  if (!review || review.status !== "published") return new Response("Yorum bulunamadı.", { status: 404 });

  if (form.get("action") === "delete") {
    const replyId = String(form.get("reply_id") ?? "");
    const reply = await db.prepare("SELECT user_id FROM review_replies WHERE id = ? AND review_id = ?")
      .bind(replyId, reviewId).first<{ user_id: string }>();
    if (!reply) return new Response("Yanıt bulunamadı.", { status: 404 });
    if (reply.user_id !== user.id) return new Response("Yetkisiz.", { status: 403 });
    await db.prepare("DELETE FROM review_replies WHERE id = ? AND user_id = ?").bind(replyId, user.id).run();
    await writeAudit(user.id, "review.reply_deleted", { reviewId, replyId });
    return communityRedirect(request, review.series_slug, "reply-deleted");
  }

  const blocked = await db.prepare(`SELECT 1 AS found FROM user_blocks
    WHERE (blocker_user_id = ? AND blocked_user_id = ?)
       OR (blocker_user_id = ? AND blocked_user_id = ?) LIMIT 1`)
    .bind(user.id, review.user_id, review.user_id, user.id).first<{ found: number }>();
  if (blocked) return communityRedirect(request, review.series_slug, "interaction-blocked");
  const allowed = await consumeRateLimit("review-reply", await requestFingerprint(request, user.id), 30, 60 * 60 * 1000);
  if (!allowed) return communityRedirect(request, review.series_slug, "reply-rate-limited");
  const body = String(form.get("body") ?? "").trim();
  if (body.length < 2 || body.length > 500) return communityRedirect(request, review.series_slug, "invalid-reply");
  const now = Date.now();
  const replyId = crypto.randomUUID();
  await db.prepare(`INSERT INTO review_replies (id, review_id, user_id, body, status, created_at, updated_at)
    VALUES (?, ?, ?, ?, 'published', ?, ?)`).bind(replyId, reviewId, user.id, body, now, now).run();
  await writeAudit(user.id, "review.replied", { reviewId, replyId });
  return communityRedirect(request, review.series_slug, "reply-saved");
}
