import { NextResponse } from "next/server";
import { assertSameOrigin, getCurrentUser } from "../../../lib/auth";
import { redirectTo } from "../../../lib/auth-http";
import { getDatabase, writeAudit } from "../../../lib/database";
import { consumeRateLimit, requestFingerprint } from "../../../lib/rate-limit";

const reasons = new Set(["spam", "harassment", "spoiler", "copyright", "other"]);

function reviewRedirect(request: Request, slug: string, state: string) {
  const url = new URL(`/${slug}`, request.url);
  url.searchParams.set("community", state);
  url.hash = "community";
  return NextResponse.redirect(url, 303);
}

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const { id } = await params;
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, "/login");
  if (!user.emailVerifiedAt) return redirectTo(request, "/account?error=Raporlama%20için%20e-posta%20adresini%20doğrula.");
  const db = await getDatabase();
  const review = await db.prepare("SELECT user_id, series_slug, status FROM reviews WHERE id = ?").bind(id).first<{ user_id: string; series_slug: string; status: string }>();
  if (!review || review.status !== "published") return new Response("Yorum bulunamadı.", { status: 404 });
  if (review.user_id === user.id) return reviewRedirect(request, review.series_slug, "cannot-report-own");
  const allowed = await consumeRateLimit("review-report", await requestFingerprint(request, user.id), 10, 24 * 60 * 60 * 1000);
  if (!allowed) return reviewRedirect(request, review.series_slug, "report-rate-limited");
  const form = await request.formData();
  const reason = String(form.get("reason") ?? "");
  const details = String(form.get("details") ?? "").trim();
  if (!reasons.has(reason) || details.length > 500) return reviewRedirect(request, review.series_slug, "invalid-report");
  const now = Date.now();
  try {
    await db.prepare(`INSERT INTO review_reports (id, review_id, reporter_user_id, reason, details, status, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, 'open', ?, ?)`)
      .bind(crypto.randomUUID(), id, user.id, reason, details || null, now, now).run();
  } catch (error) {
    if (String(error).toLowerCase().includes("unique")) return reviewRedirect(request, review.series_slug, "already-reported");
    throw error;
  }
  await writeAudit(user.id, "review.reported", { reviewId: id, reason });
  return reviewRedirect(request, review.series_slug, "reported");
}
