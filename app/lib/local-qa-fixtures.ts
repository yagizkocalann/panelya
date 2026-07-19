import fixtureManifest from "../data/local-qa-fixtures.json";
import { hashPassword } from "./auth";
import { normalizeCatalogSearch } from "./content-repository";
import { getDatabase } from "./database";

const USER_ID_GLOB = "qa_fixture_user_*";
const RECORD_ID_GLOB = "qa_fixture_*";
const SERIES_SLUG_GLOB = "qa-fixture-*";
const QA_EMAIL_GLOB = "qa-*@panelya.local";

type FixtureUser = {
  id: string;
  email: string;
  displayName: string;
  verified: boolean;
};

type FixtureSeries = {
  slug: string;
  title: string;
  eyebrow: string;
  creator: string;
  description: string;
  longDescription: string;
  storyStatus: "ongoing" | "completed";
  genres: string[];
  tone: "coral" | "mint" | "violet" | "blue" | "amber" | "rose";
  rating: number;
  publicationStatus: "draft" | "published" | "archived";
  episode: {
    id: string;
    slug: string;
    number: number;
    title: string;
    status: "draft" | "published" | "archived";
  };
};

type FixtureManifest = {
  version: number;
  users: FixtureUser[];
  series: FixtureSeries[];
  library: Array<{ userId: string; seriesSlug: string; status: "plan" | "reading" | "completed" | "paused" | "dropped"; favorite: boolean }>;
  subscriptions: Array<{ userId: string; seriesSlug: string; notify: boolean }>;
  progress: Array<{ userId: string; seriesSlug: string; episodeSlug: string; episodeNumber: number; episodeTitle: string; percent: number }>;
  reviews: Array<{ id: string; userId: string; seriesSlug: string; rating: number; comment: string; spoiler: boolean; status: "published" | "hidden" }>;
  replies: Array<{ id: string; reviewId: string; userId: string; body: string; status: "published" | "hidden" }>;
  likes: Array<{ reviewId: string; userId: string }>;
  reports: Array<{ id: string; reviewId: string; reporterUserId: string; reason: "spam" | "harassment" | "spoiler" | "copyright" | "other"; details: string; status: "open" | "resolved" | "dismissed" }>;
  outbox: Array<{ id: string; userId: string; recipient: string; kind: "verify_email" | "password_reset" | "security_notice" | "new_episode"; subject: string; body: string; dedupeKey: string; status: "queued" | "opened"; ageHours: number }>;
  messages: Array<{ id: string; name: string; email: string; subject: "general" | "creator" | "copyright" | "technical"; message: string; status: "new" | "handled" }>;
};

const fixtures = fixtureManifest as FixtureManifest;

export const LOCAL_QA_FIXTURE_VERSION = fixtures.version;
export const localQaFixtureAccounts = fixtures.users.map(({ id, email, displayName, verified }) => ({ id, email, displayName, verified }));

export type LocalQaFixtureStatus = {
  users: number;
  series: number;
  episodes: number;
  reviews: number;
  reports: number;
  outbox: number;
  messages: number;
  ready: boolean;
};

type CountRow = Omit<LocalQaFixtureStatus, "ready">;

function cleanupStatements(db: D1Database) {
  return [
    db.prepare(`DELETE FROM review_likes WHERE user_id GLOB ? OR review_id IN (
      SELECT id FROM reviews WHERE id GLOB ? OR series_slug GLOB ? OR user_id GLOB ?
    )`).bind(USER_ID_GLOB, RECORD_ID_GLOB, SERIES_SLUG_GLOB, USER_ID_GLOB),
    db.prepare(`DELETE FROM review_replies WHERE id GLOB ? OR user_id GLOB ? OR review_id IN (
      SELECT id FROM reviews WHERE id GLOB ? OR series_slug GLOB ? OR user_id GLOB ?
    )`).bind(RECORD_ID_GLOB, USER_ID_GLOB, RECORD_ID_GLOB, SERIES_SLUG_GLOB, USER_ID_GLOB),
    db.prepare(`DELETE FROM review_reports WHERE id GLOB ? OR reporter_user_id GLOB ? OR review_id IN (
      SELECT id FROM reviews WHERE id GLOB ? OR series_slug GLOB ? OR user_id GLOB ?
    )`).bind(RECORD_ID_GLOB, USER_ID_GLOB, RECORD_ID_GLOB, SERIES_SLUG_GLOB, USER_ID_GLOB),
    db.prepare("DELETE FROM reviews WHERE id GLOB ? OR user_id GLOB ? OR series_slug GLOB ?")
      .bind(RECORD_ID_GLOB, USER_ID_GLOB, SERIES_SLUG_GLOB),
    db.prepare("DELETE FROM user_blocks WHERE blocker_user_id GLOB ? OR blocked_user_id GLOB ?")
      .bind(USER_ID_GLOB, USER_ID_GLOB),
    db.prepare("DELETE FROM series_subscriptions WHERE user_id GLOB ? OR series_slug GLOB ?")
      .bind(USER_ID_GLOB, SERIES_SLUG_GLOB),
    db.prepare("DELETE FROM library_items WHERE user_id GLOB ? OR series_slug GLOB ?")
      .bind(USER_ID_GLOB, SERIES_SLUG_GLOB),
    db.prepare("DELETE FROM reading_progress WHERE user_id GLOB ? OR series_slug GLOB ?")
      .bind(USER_ID_GLOB, SERIES_SLUG_GLOB),
    db.prepare("DELETE FROM notification_outbox WHERE id GLOB ? OR user_id GLOB ? OR recipient GLOB ? OR dedupe_key GLOB 'qa-fixture:*'")
      .bind(RECORD_ID_GLOB, USER_ID_GLOB, QA_EMAIL_GLOB),
    db.prepare("DELETE FROM admin_invitations WHERE id GLOB ? OR email GLOB ?")
      .bind(RECORD_ID_GLOB, QA_EMAIL_GLOB),
    db.prepare("DELETE FROM contact_messages WHERE id GLOB ? OR email GLOB ?")
      .bind(RECORD_ID_GLOB, QA_EMAIL_GLOB),
    db.prepare("DELETE FROM copyright_notices WHERE id GLOB ? OR claimant_email GLOB ?")
      .bind(RECORD_ID_GLOB, QA_EMAIL_GLOB),
    db.prepare("DELETE FROM preview_tokens WHERE id GLOB ? OR series_slug GLOB ?")
      .bind(RECORD_ID_GLOB, SERIES_SLUG_GLOB),
    db.prepare("DELETE FROM users WHERE id GLOB ? OR email GLOB ?")
      .bind(USER_ID_GLOB, QA_EMAIL_GLOB),
    db.prepare("DELETE FROM content_series WHERE slug GLOB ?").bind(SERIES_SLUG_GLOB),
  ];
}

export async function getLocalQaFixtureStatus(): Promise<LocalQaFixtureStatus> {
  const db = await getDatabase();
  const row = await db.prepare(`SELECT
    (SELECT COUNT(*) FROM users WHERE id GLOB ?) AS users,
    (SELECT COUNT(*) FROM content_series WHERE slug GLOB ?) AS series,
    (SELECT COUNT(*) FROM content_episodes WHERE id GLOB ? OR series_slug GLOB ?) AS episodes,
    (SELECT COUNT(*) FROM reviews WHERE id GLOB ? OR series_slug GLOB ?) AS reviews,
    (SELECT COUNT(*) FROM review_reports WHERE id GLOB ?) AS reports,
    (SELECT COUNT(*) FROM notification_outbox WHERE id GLOB ? OR dedupe_key GLOB 'qa-fixture:*') AS outbox,
    (SELECT COUNT(*) FROM contact_messages WHERE id GLOB ?) AS messages`)
    .bind(USER_ID_GLOB, SERIES_SLUG_GLOB, RECORD_ID_GLOB, SERIES_SLUG_GLOB, RECORD_ID_GLOB, SERIES_SLUG_GLOB,
      RECORD_ID_GLOB, RECORD_ID_GLOB, RECORD_ID_GLOB)
    .first<CountRow>();
  const status = {
    users: Number(row?.users ?? 0),
    series: Number(row?.series ?? 0),
    episodes: Number(row?.episodes ?? 0),
    reviews: Number(row?.reviews ?? 0),
    reports: Number(row?.reports ?? 0),
    outbox: Number(row?.outbox ?? 0),
    messages: Number(row?.messages ?? 0),
  };
  return {
    ...status,
    ready: status.users === fixtures.users.length
      && status.series === fixtures.series.length
      && status.episodes === fixtures.series.length
      && status.reviews === fixtures.reviews.length
      && status.reports === fixtures.reports.length
      && status.outbox === fixtures.outbox.length
      && status.messages === fixtures.messages.length,
  };
}

export async function resetLocalQaFixtures() {
  const db = await getDatabase();
  await db.batch(cleanupStatements(db));
  return getLocalQaFixtureStatus();
}

export async function seedLocalQaFixtures(password: string) {
  const db = await getDatabase();
  const passwordHash = await hashPassword(password);
  const now = Date.now();
  const statements = cleanupStatements(db);

  for (const [index, user] of fixtures.users.entries()) {
    const timestamp = now - (fixtures.users.length - index) * 60_000;
    statements.push(db.prepare(`INSERT INTO users
      (id, email, display_name, password_hash, role, email_verified_at, created_at, updated_at)
      VALUES (?, ?, ?, ?, 'reader', ?, ?, ?)`)
      .bind(user.id, user.email, user.displayName, passwordHash, user.verified ? timestamp : null, timestamp, timestamp));
  }

  for (const [index, series] of fixtures.series.entries()) {
    const timestamp = now - index * 60 * 60 * 1000;
    const searchText = normalizeCatalogSearch([
      series.title,
      series.eyebrow,
      series.creator,
      series.description,
      ...series.genres,
    ].join(" "));
    statements.push(db.prepare(`INSERT INTO content_series (
      slug, title, eyebrow, creator, search_text, description, long_description, story_status, genres_json, tone,
      updated_label, rating, followers, is_new, cover_image, cover_position, publication_status,
      is_featured, created_at, updated_at, published_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, ?, 0, ?, ?, ?)`)
      .bind(series.slug, series.title, series.eyebrow, series.creator, searchText, series.description, series.longDescription,
        series.storyStatus, JSON.stringify(series.genres), series.tone, "QA verisi", series.rating, "QA", index < 2 ? 1 : 0,
        series.publicationStatus, timestamp, timestamp, series.publicationStatus === "published" ? timestamp : null));
    const panels = [
      { id: `${series.episode.id}-opening`, scene: `${series.title} için sentetik açılış karesi.`, caption: "Yerel QA bölümü", tone: series.tone },
      { id: `${series.episode.id}-hook`, scene: `${series.title} için sentetik karar anı.`, dialogue: "Test akışı burada devam ediyor.", tone: series.tone, align: "right" },
    ];
    statements.push(db.prepare(`INSERT INTO content_episodes (
      id, series_slug, slug, number, title, published_label, read_time, panels_json, publication_status,
      created_at, updated_at, published_at
    ) VALUES (?, ?, ?, ?, ?, ?, '2 dk', ?, ?, ?, ?, ?)`)
      .bind(series.episode.id, series.slug, series.episode.slug, series.episode.number, series.episode.title, "Yerel QA",
        JSON.stringify(panels), series.episode.status, timestamp, timestamp,
        series.episode.status === "published" ? timestamp : null));
  }

  for (const item of fixtures.library) {
    statements.push(db.prepare(`INSERT INTO library_items
      (user_id, series_slug, status, is_favorite, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)`)
      .bind(item.userId, item.seriesSlug, item.status, item.favorite ? 1 : 0, now, now));
  }
  for (const item of fixtures.subscriptions) {
    statements.push(db.prepare(`INSERT INTO series_subscriptions
      (user_id, series_slug, notify_new_episodes, created_at, updated_at) VALUES (?, ?, ?, ?, ?)`)
      .bind(item.userId, item.seriesSlug, item.notify ? 1 : 0, now, now));
  }
  for (const item of fixtures.progress) {
    statements.push(db.prepare(`INSERT INTO reading_progress
      (user_id, series_slug, episode_slug, episode_number, episode_title, percent, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)`)
      .bind(item.userId, item.seriesSlug, item.episodeSlug, item.episodeNumber, item.episodeTitle, item.percent, now));
  }
  for (const [index, review] of fixtures.reviews.entries()) {
    const timestamp = now - index * 10 * 60_000;
    statements.push(db.prepare(`INSERT INTO reviews
      (id, user_id, series_slug, rating, comment, contains_spoiler, status, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`)
      .bind(review.id, review.userId, review.seriesSlug, review.rating, review.comment, review.spoiler ? 1 : 0, review.status, timestamp, timestamp));
  }
  for (const [index, reply] of fixtures.replies.entries()) {
    const timestamp = now - index * 5 * 60_000;
    statements.push(db.prepare(`INSERT INTO review_replies
      (id, review_id, user_id, body, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)`)
      .bind(reply.id, reply.reviewId, reply.userId, reply.body, reply.status, timestamp, timestamp));
  }
  for (const like of fixtures.likes) {
    statements.push(db.prepare("INSERT INTO review_likes (review_id, user_id, created_at) VALUES (?, ?, ?)")
      .bind(like.reviewId, like.userId, now));
  }
  for (const report of fixtures.reports) {
    statements.push(db.prepare(`INSERT INTO review_reports
      (id, review_id, reporter_user_id, reason, details, status, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)`)
      .bind(report.id, report.reviewId, report.reporterUserId, report.reason, report.details, report.status, now, now));
  }
  for (const message of fixtures.outbox) {
    const createdAt = now - message.ageHours * 60 * 60 * 1000;
    statements.push(db.prepare(`INSERT INTO notification_outbox
      (id, user_id, recipient, kind, subject, body, action_url, dedupe_key, status, created_at, opened_at)
      VALUES (?, ?, ?, ?, ?, ?, NULL, ?, ?, ?, ?)`)
      .bind(message.id, message.userId, message.recipient, message.kind, message.subject, message.body, message.dedupeKey,
        message.status, createdAt, message.status === "opened" ? createdAt : null));
  }
  for (const message of fixtures.messages) {
    statements.push(db.prepare(`INSERT INTO contact_messages
      (id, name, email, subject, message, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`)
      .bind(message.id, message.name, message.email, message.subject, message.message, message.status, now, now));
  }

  await db.batch(statements);
  return getLocalQaFixtureStatus();
}
