import { getPublishedSeries } from "../../../lib/content-repository";
import { assertSameOrigin, getCurrentUser, safeReturnTo } from "../../../lib/auth";
import { redirectTo } from "../../../lib/auth-http";
import { getDatabase, writeAudit } from "../../../lib/database";

const statuses = new Set(["plan", "reading", "completed", "paused", "dropped"]);

export async function POST(request: Request, { params }: { params: Promise<{ slug: string }> }) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const { slug } = await params;
  if (!(await getPublishedSeries(slug))) return new Response("Seri bulunamadı.", { status: 404 });
  const form = await request.formData();
  const returnTo = safeReturnTo(form.get("return_to"), `/${slug}`);
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, `/login?return_to=${encodeURIComponent(returnTo)}`);
  const action = String(form.get("action") ?? "add");
  const db = await getDatabase();
  const now = Date.now();

  if (action === "remove") {
    await db.prepare("DELETE FROM library_items WHERE user_id = ? AND series_slug = ?").bind(user.id, slug).run();
  } else if (action === "favorite") {
    const current = await db.prepare("SELECT is_favorite FROM library_items WHERE user_id = ? AND series_slug = ?").bind(user.id, slug).first<{ is_favorite: number }>();
    const favorite = current ? (current.is_favorite ? 0 : 1) : 1;
    await db.prepare(`INSERT INTO library_items (user_id, series_slug, status, is_favorite, created_at, updated_at)
      VALUES (?, ?, 'plan', ?, ?, ?)
      ON CONFLICT(user_id, series_slug) DO UPDATE SET is_favorite = excluded.is_favorite, updated_at = excluded.updated_at`)
      .bind(user.id, slug, favorite, now, now).run();
  } else if (action === "status") {
    const status = String(form.get("status") ?? "plan");
    if (!statuses.has(status)) return new Response("Geçersiz durum.", { status: 400 });
    await db.prepare(`INSERT INTO library_items (user_id, series_slug, status, is_favorite, created_at, updated_at)
      VALUES (?, ?, ?, 0, ?, ?)
      ON CONFLICT(user_id, series_slug) DO UPDATE SET status = excluded.status, updated_at = excluded.updated_at`)
      .bind(user.id, slug, status, now, now).run();
  } else {
    await db.prepare(`INSERT INTO library_items (user_id, series_slug, status, is_favorite, created_at, updated_at)
      VALUES (?, ?, 'plan', 0, ?, ?)
      ON CONFLICT(user_id, series_slug) DO UPDATE SET updated_at = excluded.updated_at`)
      .bind(user.id, slug, now, now).run();
  }
  await writeAudit(user.id, `library.${action}`, { seriesSlug: slug });
  return redirectTo(request, returnTo);
}
