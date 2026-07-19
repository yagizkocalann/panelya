import { getDatabase } from "./database";

export type ReviewReplyRow = {
  id: string;
  review_id: string;
  user_id: string;
  display_name: string;
  body: string;
  status: "published" | "hidden";
  created_at: number;
  updated_at: number;
};

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
  like_count: number;
  viewer_liked: number;
  replies: ReviewReplyRow[];
};

const mutualBlockFilter = (authorExpression: string) => `NOT EXISTS (
  SELECT 1 FROM user_blocks ub
  WHERE (ub.blocker_user_id = ? AND ub.blocked_user_id = ${authorExpression})
     OR (ub.blocker_user_id = ${authorExpression} AND ub.blocked_user_id = ?)
)`;

export async function getSeriesCommunity(seriesSlug: string, currentUserId?: string) {
  let db: D1Database;
  try {
    db = await getDatabase();
  } catch {
    // Public series pages stay readable during a transient/local D1 outage; writes still fail closed.
    return { count: 0, average: null, reviews: [], currentReview: null };
  }

  const viewerSelect = currentUserId
    ? "EXISTS(SELECT 1 FROM review_likes mine WHERE mine.review_id = r.id AND mine.user_id = ?)"
    : "0";
  const visibleReviewFilter = currentUserId ? `AND ${mutualBlockFilter("r.user_id")}` : "";
  const visibleReplyFilter = currentUserId ? `AND ${mutualBlockFilter("reply.user_id")}` : "";
  const reviewBindings = currentUserId ? [currentUserId, seriesSlug, currentUserId, currentUserId] : [seriesSlug];
  const replyBindings = currentUserId ? [seriesSlug, currentUserId, currentUserId] : [seriesSlug];

  const [summary, reviewsResult, repliesResult, currentReview] = await Promise.all([
    db.prepare(`SELECT COUNT(*) AS count, AVG(rating) AS average FROM reviews
      WHERE series_slug = ? AND status = 'published'`).bind(seriesSlug).first<{ count: number; average: number | null }>(),
    db.prepare(`SELECT r.id, r.user_id, u.display_name, r.rating, r.comment, r.contains_spoiler, r.status, r.created_at, r.updated_at,
      (SELECT COUNT(*) FROM review_likes likes WHERE likes.review_id = r.id) AS like_count,
      ${viewerSelect} AS viewer_liked
      FROM reviews r JOIN users u ON u.id = r.user_id
      WHERE r.series_slug = ? AND r.status = 'published' ${visibleReviewFilter}
      ORDER BY r.updated_at DESC LIMIT 100`).bind(...reviewBindings).all<Omit<ReviewRow, "replies">>(),
    db.prepare(`SELECT reply.id, reply.review_id, reply.user_id, u.display_name, reply.body, reply.status, reply.created_at, reply.updated_at
      FROM review_replies reply
      JOIN reviews r ON r.id = reply.review_id
      JOIN users u ON u.id = reply.user_id
      WHERE r.series_slug = ? AND r.status = 'published' AND reply.status = 'published' ${visibleReplyFilter}
      ORDER BY reply.created_at ASC LIMIT 500`).bind(...replyBindings).all<ReviewReplyRow>(),
    currentUserId ? db.prepare(`SELECT r.id, r.user_id, u.display_name, r.rating, r.comment, r.contains_spoiler, r.status, r.created_at, r.updated_at,
      (SELECT COUNT(*) FROM review_likes likes WHERE likes.review_id = r.id) AS like_count,
      EXISTS(SELECT 1 FROM review_likes mine WHERE mine.review_id = r.id AND mine.user_id = ?) AS viewer_liked
      FROM reviews r JOIN users u ON u.id = r.user_id WHERE r.series_slug = ? AND r.user_id = ?`)
      .bind(currentUserId, seriesSlug, currentUserId).first<Omit<ReviewRow, "replies">>() : Promise.resolve(null),
  ]);

  const repliesByReview = new Map<string, ReviewReplyRow[]>();
  for (const reply of repliesResult.results) {
    const list = repliesByReview.get(reply.review_id) ?? [];
    list.push(reply);
    repliesByReview.set(reply.review_id, list);
  }
  const reviews = reviewsResult.results.map((review) => ({
    ...review,
    like_count: Number(review.like_count),
    viewer_liked: Number(review.viewer_liked),
    replies: repliesByReview.get(review.id) ?? [],
  }));
  const own = currentReview ? {
    ...currentReview,
    like_count: Number(currentReview.like_count),
    viewer_liked: Number(currentReview.viewer_liked),
    replies: repliesByReview.get(currentReview.id) ?? [],
  } : null;
  return {
    count: Number(summary?.count ?? 0),
    average: summary?.average == null ? null : Number(summary.average),
    reviews,
    currentReview: own,
  };
}

export async function getBlockedUsers(userId: string) {
  const db = await getDatabase();
  const rows = await db.prepare(`SELECT u.id, u.display_name, ub.created_at
    FROM user_blocks ub JOIN users u ON u.id = ub.blocked_user_id
    WHERE ub.blocker_user_id = ? ORDER BY ub.created_at DESC`).bind(userId).all<{ id: string; display_name: string; created_at: number }>();
  return rows.results;
}
