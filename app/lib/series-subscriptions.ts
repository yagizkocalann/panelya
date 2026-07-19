import { getDatabase } from "./database";
import { sendNotification } from "./notifications";

export type SeriesReaderState = {
  inLibrary: boolean;
  isFavorite: boolean;
  libraryStatus: string | null;
  isFollowing: boolean;
  notifyNewEpisodes: boolean;
};

type LibraryStateRow = { status: string; is_favorite: number };
type SubscriptionRow = { series_slug: string; notify_new_episodes: number; updated_at: number };
type SubscriberRow = { user_id: string; email: string };

export async function getSeriesReaderState(userId: string, seriesSlug: string): Promise<SeriesReaderState> {
  const db = await getDatabase();
  const [library, subscription] = await db.batch([
    db.prepare("SELECT status, is_favorite FROM library_items WHERE user_id = ? AND series_slug = ?").bind(userId, seriesSlug),
    db.prepare("SELECT notify_new_episodes FROM series_subscriptions WHERE user_id = ? AND series_slug = ?").bind(userId, seriesSlug),
  ]);
  const libraryRow = library.results?.[0] as LibraryStateRow | undefined;
  const subscriptionRow = subscription.results?.[0] as Pick<SubscriptionRow, "notify_new_episodes"> | undefined;
  return {
    inLibrary: Boolean(libraryRow),
    isFavorite: Boolean(libraryRow?.is_favorite),
    libraryStatus: libraryRow?.status ?? null,
    isFollowing: Boolean(subscriptionRow),
    notifyNewEpisodes: Boolean(subscriptionRow?.notify_new_episodes),
  };
}

export async function listUserSeriesSubscriptions(userId: string) {
  const db = await getDatabase();
  const result = await db.prepare(`SELECT series_slug, notify_new_episodes, updated_at
    FROM series_subscriptions WHERE user_id = ? ORDER BY updated_at DESC`).bind(userId).all<SubscriptionRow>();
  return result.results;
}

export async function toggleSeriesFollow(userId: string, seriesSlug: string) {
  const db = await getDatabase();
  const current = await db.prepare("SELECT notify_new_episodes FROM series_subscriptions WHERE user_id = ? AND series_slug = ?")
    .bind(userId, seriesSlug).first<{ notify_new_episodes: number }>();
  if (current) {
    await db.prepare("DELETE FROM series_subscriptions WHERE user_id = ? AND series_slug = ?").bind(userId, seriesSlug).run();
    return { isFollowing: false, notifyNewEpisodes: false };
  }
  const now = Date.now();
  await db.prepare(`INSERT INTO series_subscriptions (user_id, series_slug, notify_new_episodes, created_at, updated_at)
    VALUES (?, ?, 0, ?, ?)`)
    .bind(userId, seriesSlug, now, now).run();
  return { isFollowing: true, notifyNewEpisodes: false };
}

export async function toggleNewEpisodeNotifications(userId: string, seriesSlug: string) {
  const db = await getDatabase();
  const current = await db.prepare("SELECT notify_new_episodes FROM series_subscriptions WHERE user_id = ? AND series_slug = ?")
    .bind(userId, seriesSlug).first<{ notify_new_episodes: number }>();
  const nextValue = current?.notify_new_episodes ? 0 : 1;
  const now = Date.now();
  await db.prepare(`INSERT INTO series_subscriptions (user_id, series_slug, notify_new_episodes, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(user_id, series_slug) DO UPDATE SET notify_new_episodes = excluded.notify_new_episodes, updated_at = excluded.updated_at`)
    .bind(userId, seriesSlug, nextValue, now, now).run();
  return { isFollowing: true, notifyNewEpisodes: Boolean(nextValue) };
}

export async function dispatchNewEpisodeNotifications(input: {
  seriesSlug: string;
  seriesTitle: string;
  episodeSlug: string;
  episodeTitle: string;
  episodeUrl: string;
}) {
  const db = await getDatabase();
  const subscribers = await db.prepare(`SELECT s.user_id, u.email
    FROM series_subscriptions s
    JOIN users u ON u.id = s.user_id
    WHERE s.series_slug = ? AND s.notify_new_episodes = 1 AND u.email_verified_at IS NOT NULL`)
    .bind(input.seriesSlug).all<SubscriberRow>();
  let queued = 0;
  let failed = 0;
  for (const subscriber of subscribers.results) {
    try {
      const result = await sendNotification({
        userId: subscriber.user_id,
        recipient: subscriber.email,
        kind: "new_episode",
        subject: `${input.seriesTitle}: ${input.episodeTitle} yayında`,
        body: `${input.seriesTitle} serisinin yeni bölümü “${input.episodeTitle}” şimdi okunabilir.`,
        actionUrl: input.episodeUrl,
        dedupeKey: `new-episode:${subscriber.user_id}:${input.seriesSlug}:${input.episodeSlug}`,
      });
      if (result.accepted) queued += 1;
    } catch {
      failed += 1;
    }
  }
  return { subscribers: subscribers.results.length, queued, failed };
}
