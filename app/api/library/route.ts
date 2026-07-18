import { getCurrentUser } from "../../lib/auth";
import { getDatabase } from "../../lib/database";

export async function GET() {
  const user = await getCurrentUser();
  if (!user) return Response.json({ authenticated: false, items: [] }, { status: 401 });
  const db = await getDatabase();
  const result = await db.prepare("SELECT series_slug AS seriesSlug, status, is_favorite AS isFavorite, updated_at AS updatedAt FROM library_items WHERE user_id = ? ORDER BY updated_at DESC").bind(user.id).all();
  return Response.json({ authenticated: true, items: result.results }, { headers: { "cache-control": "no-store" } });
}
