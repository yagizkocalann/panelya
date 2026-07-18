import { getDatabase } from "./database";

export type ReviewRow = {
  id: string;
  user_id: string;
  display_name: string;
  rating: number;
  comment: string | null;
  contains_spoiler: number;
  status: "published" | "hidden";
  created_at: number;
  updated_at: number;
};

export async function getSeriesCommunity(seriesSlug: string, currentUserId?: string) {
  let db: D1Database;
  try {
    db = await getDatabase();
  } catch {
    // Public series pages stay readable during a transient/local D1 outage; writes still fail closed.
    return { count: 0, average: null, reviews: [], currentReview: null };
  }
  const [summary, reviews, currentReview] = await Promise.all([
    db.prepare(`SELECT COUNT(*) AS count, AVG(rating) AS average FROM reviews
      WHERE series_slug = ? AND status = 'published'`).bind(seriesSlug).first<{ count: number; average: number | null }>(),
    db.prepare(`SELECT r.id, r.user_id, u.display_name, r.rating, r.comment, r.contains_spoiler, r.status, r.created_at, r.updated_at
      FROM reviews r JOIN users u ON u.id = r.user_id
      WHERE r.series_slug = ? AND r.status = 'published'
      ORDER BY r.updated_at DESC LIMIT 100`).bind(seriesSlug).all<ReviewRow>(),
    currentUserId ? db.prepare(`SELECT r.id, r.user_id, u.display_name, r.rating, r.comment, r.contains_spoiler, r.status, r.created_at, r.updated_at
      FROM reviews r JOIN users u ON u.id = r.user_id WHERE r.series_slug = ? AND r.user_id = ?`)
      .bind(seriesSlug, currentUserId).first<ReviewRow>() : Promise.resolve(null),
  ]);
  return {
    count: Number(summary?.count ?? 0),
    average: summary?.average == null ? null : Number(summary.average),
    reviews: reviews.results,
    currentReview: currentReview ?? null,
  };
}
