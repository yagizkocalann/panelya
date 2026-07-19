import { sql } from "drizzle-orm";
import { index, integer, primaryKey, real, sqliteTable, text, uniqueIndex } from "drizzle-orm/sqlite-core";

export const users = sqliteTable("users", {
  id: text("id").primaryKey(),
  email: text("email").notNull(),
  displayName: text("display_name").notNull(),
  passwordHash: text("password_hash").notNull(),
  role: text("role", { enum: ["reader", "admin"] }).notNull().default("reader"),
  emailVerifiedAt: integer("email_verified_at"),
  createdAt: integer("created_at").notNull(),
  updatedAt: integer("updated_at").notNull(),
}, (table) => [uniqueIndex("users_email_unique").on(table.email)]);

export const sessions = sqliteTable("sessions", {
  tokenHash: text("token_hash").primaryKey(),
  userId: text("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  expiresAt: integer("expires_at").notNull(),
  createdAt: integer("created_at").notNull(),
  userAgent: text("user_agent"),
});

export const accountTokens = sqliteTable("account_tokens", {
  id: text("id").primaryKey(),
  tokenHash: text("token_hash").notNull(),
  userId: text("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  purpose: text("purpose", { enum: ["verify_email", "password_reset"] }).notNull(),
  targetEmail: text("target_email").notNull(),
  expiresAt: integer("expires_at").notNull(),
  usedAt: integer("used_at"),
  createdAt: integer("created_at").notNull(),
}, (table) => [uniqueIndex("account_tokens_hash_unique").on(table.tokenHash)]);

export const notificationOutbox = sqliteTable("notification_outbox", {
  id: text("id").primaryKey(),
  userId: text("user_id").references(() => users.id, { onDelete: "set null" }),
  recipient: text("recipient").notNull(),
  kind: text("kind", { enum: ["verify_email", "password_reset", "security_notice", "new_episode"] }).notNull(),
  subject: text("subject").notNull(),
  body: text("body").notNull(),
  actionUrl: text("action_url"),
  dedupeKey: text("dedupe_key"),
  status: text("status", { enum: ["queued", "opened"] }).notNull().default("queued"),
  createdAt: integer("created_at").notNull(),
  openedAt: integer("opened_at"),
}, (table) => [uniqueIndex("notification_outbox_dedupe_unique").on(table.dedupeKey)]);

export const adminInvitations = sqliteTable("admin_invitations", {
  id: text("id").primaryKey(),
  email: text("email").notNull(),
  tokenHash: text("token_hash").notNull(),
  invitedByUserId: text("invited_by_user_id").references(() => users.id, { onDelete: "set null" }),
  status: text("status", { enum: ["pending", "accepted", "revoked"] }).notNull().default("pending"),
  expiresAt: integer("expires_at").notNull(),
  acceptedAt: integer("accepted_at"),
  revokedAt: integer("revoked_at"),
  createdAt: integer("created_at").notNull(),
  updatedAt: integer("updated_at").notNull(),
}, (table) => [
  uniqueIndex("admin_invitations_token_unique").on(table.tokenHash),
  uniqueIndex("admin_invitations_pending_email_unique").on(table.email).where(sql`${table.status} = 'pending'`),
  index("admin_invitations_email_status_idx").on(table.email, table.status, table.createdAt),
  index("admin_invitations_expiry_idx").on(table.expiresAt),
]);

export const rateLimitBuckets = sqliteTable("rate_limit_buckets", {
  key: text("key").primaryKey(),
  count: integer("count").notNull(),
  resetAt: integer("reset_at").notNull(),
});

export const libraryItems = sqliteTable("library_items", {
  userId: text("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  seriesSlug: text("series_slug").notNull(),
  status: text("status", { enum: ["plan", "reading", "completed", "paused", "dropped"] }).notNull().default("plan"),
  isFavorite: integer("is_favorite", { mode: "boolean" }).notNull().default(false),
  createdAt: integer("created_at").notNull(),
  updatedAt: integer("updated_at").notNull(),
}, (table) => [primaryKey({ columns: [table.userId, table.seriesSlug] })]);

export const seriesSubscriptions = sqliteTable("series_subscriptions", {
  userId: text("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  seriesSlug: text("series_slug").notNull(),
  notifyNewEpisodes: integer("notify_new_episodes", { mode: "boolean" }).notNull().default(false),
  createdAt: integer("created_at").notNull(),
  updatedAt: integer("updated_at").notNull(),
}, (table) => [
  primaryKey({ columns: [table.userId, table.seriesSlug] }),
  index("series_subscriptions_series_idx").on(table.seriesSlug, table.notifyNewEpisodes),
]);

export const readingProgress = sqliteTable("reading_progress", {
  userId: text("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  seriesSlug: text("series_slug").notNull(),
  episodeSlug: text("episode_slug").notNull(),
  episodeNumber: integer("episode_number").notNull(),
  episodeTitle: text("episode_title").notNull(),
  percent: integer("percent").notNull().default(0),
  updatedAt: integer("updated_at").notNull(),
}, (table) => [primaryKey({ columns: [table.userId, table.seriesSlug] })]);

export const auditEvents = sqliteTable("audit_events", {
  id: text("id").primaryKey(),
  userId: text("user_id").references(() => users.id, { onDelete: "set null" }),
  action: text("action").notNull(),
  metadata: text("metadata"),
  createdAt: integer("created_at").notNull(),
});

export const contactMessages = sqliteTable("contact_messages", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
  email: text("email").notNull(),
  subject: text("subject", { enum: ["general", "creator", "copyright", "technical"] }).notNull().default("general"),
  message: text("message").notNull(),
  status: text("status", { enum: ["new", "handled"] }).notNull().default("new"),
  createdAt: integer("created_at").notNull(),
  updatedAt: integer("updated_at").notNull(),
});

export const reviews = sqliteTable("reviews", {
  id: text("id").primaryKey(),
  userId: text("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  seriesSlug: text("series_slug").notNull(),
  rating: integer("rating").notNull(),
  comment: text("comment"),
  containsSpoiler: integer("contains_spoiler", { mode: "boolean" }).notNull().default(false),
  status: text("status", { enum: ["published", "hidden"] }).notNull().default("published"),
  createdAt: integer("created_at").notNull(),
  updatedAt: integer("updated_at").notNull(),
}, (table) => [uniqueIndex("reviews_user_series_unique").on(table.userId, table.seriesSlug)]);

export const reviewReports = sqliteTable("review_reports", {
  id: text("id").primaryKey(),
  reviewId: text("review_id").notNull().references(() => reviews.id, { onDelete: "cascade" }),
  reporterUserId: text("reporter_user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  reason: text("reason", { enum: ["spam", "harassment", "spoiler", "copyright", "other"] }).notNull(),
  details: text("details"),
  status: text("status", { enum: ["open", "resolved", "dismissed"] }).notNull().default("open"),
  createdAt: integer("created_at").notNull(),
  updatedAt: integer("updated_at").notNull(),
}, (table) => [uniqueIndex("review_reports_reporter_unique").on(table.reviewId, table.reporterUserId)]);

export const contentSeries = sqliteTable("content_series", {
  slug: text("slug").primaryKey(),
  title: text("title").notNull(),
  eyebrow: text("eyebrow").notNull(),
  creator: text("creator").notNull(),
  searchText: text("search_text").notNull().default(""),
  description: text("description").notNull(),
  longDescription: text("long_description").notNull(),
  storyStatus: text("story_status", { enum: ["ongoing", "completed"] }).notNull().default("ongoing"),
  genresJson: text("genres_json").notNull().default("[]"),
  tone: text("tone", { enum: ["coral", "mint", "violet", "blue", "amber", "rose"] }).notNull().default("coral"),
  updatedLabel: text("updated_label").notNull().default("Taslak"),
  rating: real("rating").notNull().default(0),
  followers: text("followers").notNull().default("Yeni"),
  isNew: integer("is_new", { mode: "boolean" }).notNull().default(true),
  coverImage: text("cover_image"),
  coverPosition: text("cover_position"),
  publicationStatus: text("publication_status", { enum: ["draft", "published", "archived"] }).notNull().default("draft"),
  isFeatured: integer("is_featured", { mode: "boolean" }).notNull().default(false),
  createdAt: integer("created_at").notNull(),
  updatedAt: integer("updated_at").notNull(),
  publishedAt: integer("published_at"),
}, (table) => [
  index("content_series_publication_idx").on(table.publicationStatus, table.isFeatured, table.updatedAt),
  index("content_series_discovery_updated_idx").on(table.publicationStatus, table.storyStatus, table.updatedAt, table.slug),
  index("content_series_discovery_rating_idx").on(table.publicationStatus, table.storyStatus, table.rating, table.slug),
  index("content_series_discovery_title_idx").on(table.publicationStatus, table.storyStatus, table.title, table.slug),
]);

export const contentEpisodes = sqliteTable("content_episodes", {
  id: text("id").primaryKey(),
  seriesSlug: text("series_slug").notNull().references(() => contentSeries.slug, { onDelete: "cascade" }),
  slug: text("slug").notNull(),
  number: integer("number").notNull(),
  title: text("title").notNull(),
  publishedLabel: text("published_label").notNull(),
  readTime: text("read_time").notNull(),
  panelsJson: text("panels_json").notNull().default("[]"),
  publicationStatus: text("publication_status", { enum: ["draft", "published", "archived"] }).notNull().default("draft"),
  createdAt: integer("created_at").notNull(),
  updatedAt: integer("updated_at").notNull(),
  publishedAt: integer("published_at"),
}, (table) => [
  uniqueIndex("content_episodes_series_slug_unique").on(table.seriesSlug, table.slug),
  uniqueIndex("content_episodes_series_number_unique").on(table.seriesSlug, table.number),
  index("content_episodes_series_idx").on(table.seriesSlug, table.publicationStatus, table.number),
]);

export const mediaAssets = sqliteTable("media_assets", {
  id: text("id").primaryKey(),
  storageKey: text("storage_key").notNull(),
  originalFilename: text("original_filename").notNull(),
  mimeType: text("mime_type", { enum: ["image/jpeg", "image/png", "image/webp"] }).notNull(),
  byteSize: integer("byte_size").notNull(),
  width: integer("width").notNull(),
  height: integer("height").notNull(),
  kind: text("kind", { enum: ["cover", "panel"] }).notNull(),
  seriesSlug: text("series_slug").notNull().references(() => contentSeries.slug, { onDelete: "cascade" }),
  episodeSlug: text("episode_slug"),
  createdByUserId: text("created_by_user_id").references(() => users.id, { onDelete: "set null" }),
  createdAt: integer("created_at").notNull(),
}, (table) => [
  uniqueIndex("media_assets_storage_key_unique").on(table.storageKey),
  index("media_assets_series_idx").on(table.seriesSlug, table.episodeSlug, table.createdAt),
]);

export const mediaVariants = sqliteTable("media_variants", {
  id: text("id").primaryKey(),
  assetId: text("asset_id").notNull().references(() => mediaAssets.id, { onDelete: "cascade" }),
  storageKey: text("storage_key").notNull(),
  mimeType: text("mime_type", { enum: ["image/webp"] }).notNull(),
  byteSize: integer("byte_size").notNull(),
  width: integer("width").notNull(),
  height: integer("height").notNull(),
  createdAt: integer("created_at").notNull(),
}, (table) => [
  uniqueIndex("media_variants_asset_width_unique").on(table.assetId, table.width, table.mimeType),
  uniqueIndex("media_variants_storage_key_unique").on(table.storageKey),
  index("media_variants_asset_idx").on(table.assetId, table.width),
]);

export const mediaDerivativeJobs = sqliteTable("media_derivative_jobs", {
  id: text("id").primaryKey(),
  assetId: text("asset_id").notNull().references(() => mediaAssets.id, { onDelete: "cascade" }),
  targetWidth: integer("target_width").notNull(),
  format: text("format", { enum: ["webp"] }).notNull().default("webp"),
  status: text("status", { enum: ["queued", "processing", "completed", "failed"] }).notNull().default("queued"),
  attempts: integer("attempts").notNull().default(0),
  error: text("error"),
  dispatchMode: text("dispatch_mode", { enum: ["local_browser", "cloudflare_queue"] }).notNull().default("local_browser"),
  dispatchStatus: text("dispatch_status", { enum: ["local", "pending", "sent", "failed"] }).notNull().default("local"),
  dispatchAttempts: integer("dispatch_attempts").notNull().default(0),
  dispatchError: text("dispatch_error"),
  dispatchedAt: integer("dispatched_at"),
  createdAt: integer("created_at").notNull(),
  startedAt: integer("started_at"),
  completedAt: integer("completed_at"),
  updatedAt: integer("updated_at").notNull(),
}, (table) => [
  uniqueIndex("media_derivative_jobs_target_unique").on(table.assetId, table.targetWidth, table.format),
  index("media_derivative_jobs_status_idx").on(table.status, table.createdAt),
  index("media_derivative_jobs_dispatch_idx").on(table.dispatchStatus, table.createdAt),
]);

export const previewTokens = sqliteTable("preview_tokens", {
  id: text("id").primaryKey(),
  tokenHash: text("token_hash").notNull(),
  seriesSlug: text("series_slug").notNull().references(() => contentSeries.slug, { onDelete: "cascade" }),
  episodeSlug: text("episode_slug"),
  createdByUserId: text("created_by_user_id").references(() => users.id, { onDelete: "set null" }),
  expiresAt: integer("expires_at").notNull(),
  revokedAt: integer("revoked_at"),
  createdAt: integer("created_at").notNull(),
}, (table) => [
  uniqueIndex("preview_tokens_hash_unique").on(table.tokenHash),
  index("preview_tokens_scope_idx").on(table.seriesSlug, table.episodeSlug, table.expiresAt),
  index("preview_tokens_expiry_idx").on(table.expiresAt),
]);
