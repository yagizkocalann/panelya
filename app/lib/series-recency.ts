export const NEW_SERIES_WINDOW_MS = 30 * 24 * 60 * 60 * 1000;

export function isRecentlyPublished(publishedAt: number | null, now = Date.now()) {
  return publishedAt !== null && publishedAt <= now && now - publishedAt < NEW_SERIES_WINDOW_MS;
}
