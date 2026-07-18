import { assertSameOrigin, getCurrentUser } from "../../../../../lib/auth";
import { redirectTo } from "../../../../../lib/auth-http";
import { getDatabase, writeAudit } from "../../../../../lib/database";

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, "/login?return_to=/moderation");
  if (user.role !== "admin") return new Response("Yetkisiz.", { status: 403 });
  const { id } = await params;
  const form = await request.formData();
  const action = form.get("action") === "publish" ? "publish" : "hide";
  const db = await getDatabase();
  const now = Date.now();
  await db.batch([
    db.prepare("UPDATE reviews SET status = ?, updated_at = ? WHERE id = ?").bind(action === "hide" ? "hidden" : "published", now, id),
    db.prepare("UPDATE review_reports SET status = ?, updated_at = ? WHERE review_id = ? AND status = 'open'")
      .bind(action === "hide" ? "resolved" : "dismissed", now, id),
  ]);
  await writeAudit(user.id, `moderation.review_${action}`, { reviewId: id });
  return redirectTo(request, "/moderation");
}
