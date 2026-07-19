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
  await db.prepare("UPDATE review_replies SET status = ?, updated_at = ? WHERE id = ?")
    .bind(action === "hide" ? "hidden" : "published", Date.now(), id).run();
  await writeAudit(user.id, `moderation.reply_${action}`, { replyId: id });
  return redirectTo(request, "/moderation#recent-replies");
}
