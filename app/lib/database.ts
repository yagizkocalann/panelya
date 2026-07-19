let schemaReady: Promise<void> | null = null;

export async function getDatabase() {
  const { env } = await import("cloudflare:workers");
  if (!env.DB) throw new Error("D1 binding `DB` is unavailable.");
  schemaReady ??= ensureSchema(env.DB);
  await schemaReady;
  return env.DB;
}

async function ensureSchema(db: D1Database) {
  await db.batch([
    db.prepare(`CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY NOT NULL,
      email TEXT NOT NULL UNIQUE,
      display_name TEXT NOT NULL,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'reader' CHECK(role IN ('reader','admin')),
      email_verified_at INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS account_tokens (
      id TEXT PRIMARY KEY NOT NULL,
      token_hash TEXT NOT NULL UNIQUE,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      purpose TEXT NOT NULL CHECK(purpose IN ('verify_email','password_reset')),
      target_email TEXT NOT NULL,
      expires_at INTEGER NOT NULL,
      used_at INTEGER,
      created_at INTEGER NOT NULL
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS notification_outbox (
      id TEXT PRIMARY KEY NOT NULL,
      user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
      recipient TEXT NOT NULL,
      kind TEXT NOT NULL CHECK(kind IN ('verify_email','password_reset','security_notice','new_episode')),
      subject TEXT NOT NULL,
      body TEXT NOT NULL,
      action_url TEXT,
      dedupe_key TEXT,
      status TEXT NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','opened')),
      created_at INTEGER NOT NULL,
      opened_at INTEGER
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS admin_invitations (
      id TEXT PRIMARY KEY NOT NULL,
      email TEXT NOT NULL,
      token_hash TEXT NOT NULL UNIQUE,
      invited_by_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
      status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','accepted','revoked')),
      expires_at INTEGER NOT NULL,
      accepted_at INTEGER,
      revoked_at INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS rate_limit_buckets (
      key TEXT PRIMARY KEY NOT NULL,
      count INTEGER NOT NULL,
      reset_at INTEGER NOT NULL
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS sessions (
      token_hash TEXT PRIMARY KEY NOT NULL,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      expires_at INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      user_agent TEXT
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS library_items (
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      series_slug TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'plan' CHECK(status IN ('plan','reading','completed','paused','dropped')),
      is_favorite INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (user_id, series_slug)
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS series_subscriptions (
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      series_slug TEXT NOT NULL,
      notify_new_episodes INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (user_id, series_slug)
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS audit_events (
      id TEXT PRIMARY KEY NOT NULL,
      user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
      action TEXT NOT NULL,
      metadata TEXT,
      created_at INTEGER NOT NULL
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS reading_progress (
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      series_slug TEXT NOT NULL,
      episode_slug TEXT NOT NULL,
      episode_number INTEGER NOT NULL,
      episode_title TEXT NOT NULL,
      percent INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (user_id, series_slug)
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS contact_messages (
      id TEXT PRIMARY KEY NOT NULL,
      name TEXT NOT NULL,
      email TEXT NOT NULL,
      subject TEXT NOT NULL DEFAULT 'general' CHECK(subject IN ('general','creator','copyright','technical')),
      message TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'new' CHECK(status IN ('new','handled')),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS copyright_notices (
      id TEXT PRIMARY KEY NOT NULL,
      reference_code TEXT NOT NULL UNIQUE,
      access_token_hash TEXT NOT NULL UNIQUE,
      claimant_name TEXT NOT NULL,
      claimant_email TEXT NOT NULL,
      claimant_role TEXT NOT NULL CHECK(claimant_role IN ('rights_holder','authorized_representative')),
      work_description TEXT NOT NULL,
      original_work_url TEXT,
      content_url TEXT NOT NULL,
      rights_explanation TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'submitted' CHECK(status IN ('submitted','under_review','needs_information','action_taken','rejected')),
      public_response TEXT,
      access_expires_at INTEGER NOT NULL,
      resolved_at INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS reviews (
      id TEXT PRIMARY KEY NOT NULL,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      series_slug TEXT NOT NULL,
      rating INTEGER NOT NULL CHECK(rating BETWEEN 1 AND 5),
      comment TEXT,
      contains_spoiler INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'published' CHECK(status IN ('published','hidden')),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      UNIQUE(user_id, series_slug)
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS review_reports (
      id TEXT PRIMARY KEY NOT NULL,
      review_id TEXT NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
      reporter_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      reason TEXT NOT NULL CHECK(reason IN ('spam','harassment','spoiler','copyright','other')),
      details TEXT,
      status TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open','resolved','dismissed')),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      UNIQUE(review_id, reporter_user_id)
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS review_replies (
      id TEXT PRIMARY KEY NOT NULL,
      review_id TEXT NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      body TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'published' CHECK(status IN ('published','hidden')),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS review_likes (
      review_id TEXT NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      created_at INTEGER NOT NULL,
      PRIMARY KEY (review_id, user_id)
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS user_blocks (
      blocker_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      blocked_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      created_at INTEGER NOT NULL,
      PRIMARY KEY (blocker_user_id, blocked_user_id),
      CHECK(blocker_user_id <> blocked_user_id)
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS content_series (
      slug TEXT PRIMARY KEY NOT NULL,
      title TEXT NOT NULL,
      eyebrow TEXT NOT NULL,
      creator TEXT NOT NULL,
      search_text TEXT NOT NULL DEFAULT '',
      description TEXT NOT NULL,
      long_description TEXT NOT NULL,
      story_status TEXT NOT NULL DEFAULT 'ongoing' CHECK(story_status IN ('ongoing','completed')),
      genres_json TEXT NOT NULL DEFAULT '[]',
      tone TEXT NOT NULL DEFAULT 'coral' CHECK(tone IN ('coral','mint','violet','blue','amber','rose')),
      updated_label TEXT NOT NULL DEFAULT 'Taslak',
      rating REAL NOT NULL DEFAULT 0,
      followers TEXT NOT NULL DEFAULT 'Yeni',
      is_new INTEGER NOT NULL DEFAULT 1,
      cover_image TEXT,
      cover_position TEXT,
      publication_status TEXT NOT NULL DEFAULT 'draft' CHECK(publication_status IN ('draft','published','archived')),
      is_featured INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      published_at INTEGER
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS content_episodes (
      id TEXT PRIMARY KEY NOT NULL,
      series_slug TEXT NOT NULL REFERENCES content_series(slug) ON DELETE CASCADE,
      slug TEXT NOT NULL,
      number INTEGER NOT NULL,
      title TEXT NOT NULL,
      published_label TEXT NOT NULL,
      read_time TEXT NOT NULL,
      panels_json TEXT NOT NULL DEFAULT '[]',
      publication_status TEXT NOT NULL DEFAULT 'draft' CHECK(publication_status IN ('draft','published','archived')),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      published_at INTEGER,
      UNIQUE(series_slug, slug),
      UNIQUE(series_slug, number)
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS media_assets (
      id TEXT PRIMARY KEY NOT NULL,
      storage_key TEXT NOT NULL UNIQUE,
      original_filename TEXT NOT NULL,
      mime_type TEXT NOT NULL CHECK(mime_type IN ('image/jpeg','image/png','image/webp')),
      byte_size INTEGER NOT NULL,
      width INTEGER NOT NULL,
      height INTEGER NOT NULL,
      kind TEXT NOT NULL CHECK(kind IN ('cover','panel')),
      series_slug TEXT NOT NULL REFERENCES content_series(slug) ON DELETE CASCADE,
      episode_slug TEXT,
      created_by_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
      created_at INTEGER NOT NULL
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS media_variants (
      id TEXT PRIMARY KEY NOT NULL,
      asset_id TEXT NOT NULL REFERENCES media_assets(id) ON DELETE CASCADE,
      storage_key TEXT NOT NULL UNIQUE,
      mime_type TEXT NOT NULL CHECK(mime_type = 'image/webp'),
      byte_size INTEGER NOT NULL,
      width INTEGER NOT NULL,
      height INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      UNIQUE(asset_id, width, mime_type)
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS media_derivative_jobs (
      id TEXT PRIMARY KEY NOT NULL,
      asset_id TEXT NOT NULL REFERENCES media_assets(id) ON DELETE CASCADE,
      target_width INTEGER NOT NULL,
      format TEXT NOT NULL DEFAULT 'webp' CHECK(format = 'webp'),
      status TEXT NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','processing','completed','failed')),
      attempts INTEGER NOT NULL DEFAULT 0,
      error TEXT,
      dispatch_mode TEXT NOT NULL DEFAULT 'local_browser' CHECK(dispatch_mode IN ('local_browser','cloudflare_queue')),
      dispatch_status TEXT NOT NULL DEFAULT 'local' CHECK(dispatch_status IN ('local','pending','sent','failed')),
      dispatch_attempts INTEGER NOT NULL DEFAULT 0,
      dispatch_error TEXT,
      dispatched_at INTEGER,
      created_at INTEGER NOT NULL,
      started_at INTEGER,
      completed_at INTEGER,
      updated_at INTEGER NOT NULL,
      UNIQUE(asset_id, target_width, format)
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS preview_tokens (
      id TEXT PRIMARY KEY NOT NULL,
      token_hash TEXT NOT NULL UNIQUE,
      series_slug TEXT NOT NULL REFERENCES content_series(slug) ON DELETE CASCADE,
      episode_slug TEXT,
      created_by_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
      expires_at INTEGER NOT NULL,
      revoked_at INTEGER,
      created_at INTEGER NOT NULL
    )`),
    db.prepare("CREATE INDEX IF NOT EXISTS sessions_user_idx ON sessions(user_id)"),
    db.prepare("CREATE INDEX IF NOT EXISTS sessions_expiry_idx ON sessions(expires_at)"),
    db.prepare("CREATE INDEX IF NOT EXISTS library_user_idx ON library_items(user_id, updated_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS progress_user_idx ON reading_progress(user_id, updated_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS contact_status_idx ON contact_messages(status, created_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS copyright_notices_status_idx ON copyright_notices(status, created_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS copyright_notices_access_expiry_idx ON copyright_notices(access_expires_at)"),
    db.prepare("CREATE INDEX IF NOT EXISTS account_tokens_user_idx ON account_tokens(user_id, purpose, created_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS account_tokens_expiry_idx ON account_tokens(expires_at)"),
    db.prepare("CREATE INDEX IF NOT EXISTS outbox_created_idx ON notification_outbox(created_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS series_subscriptions_series_idx ON series_subscriptions(series_slug, notify_new_episodes)"),
    db.prepare("CREATE INDEX IF NOT EXISTS admin_invitations_email_status_idx ON admin_invitations(email, status, created_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS admin_invitations_expiry_idx ON admin_invitations(expires_at)"),
    db.prepare("CREATE UNIQUE INDEX IF NOT EXISTS admin_invitations_pending_email_unique ON admin_invitations(email) WHERE status = 'pending'"),
    db.prepare("CREATE INDEX IF NOT EXISTS reviews_series_idx ON reviews(series_slug, status, updated_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS review_reports_status_idx ON review_reports(status, created_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS review_reports_review_idx ON review_reports(review_id, status)"),
    db.prepare("CREATE INDEX IF NOT EXISTS review_replies_review_idx ON review_replies(review_id, status, created_at)"),
    db.prepare("CREATE INDEX IF NOT EXISTS review_replies_user_idx ON review_replies(user_id, created_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS user_blocks_blocked_idx ON user_blocks(blocked_user_id, created_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS content_series_publication_idx ON content_series(publication_status, is_featured DESC, updated_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS content_series_discovery_updated_idx ON content_series(publication_status, story_status, updated_at DESC, slug)"),
    db.prepare("CREATE INDEX IF NOT EXISTS content_series_discovery_rating_idx ON content_series(publication_status, story_status, rating DESC, slug)"),
    db.prepare("CREATE INDEX IF NOT EXISTS content_series_discovery_title_idx ON content_series(publication_status, story_status, title COLLATE NOCASE, slug)"),
    db.prepare("CREATE INDEX IF NOT EXISTS content_episodes_series_idx ON content_episodes(series_slug, publication_status, number DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS media_assets_series_idx ON media_assets(series_slug, episode_slug, created_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS media_variants_asset_idx ON media_variants(asset_id, width)"),
    db.prepare("CREATE INDEX IF NOT EXISTS media_derivative_jobs_status_idx ON media_derivative_jobs(status, created_at)"),
    db.prepare("CREATE INDEX IF NOT EXISTS preview_tokens_scope_idx ON preview_tokens(series_slug, episode_slug, expires_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS preview_tokens_expiry_idx ON preview_tokens(expires_at)"),
  ]);

  const userColumns = await db.prepare("PRAGMA table_info(users)").all<{ name: string }>();
  if (!userColumns.results.some((column) => column.name === "email_verified_at")) {
    await db.prepare("ALTER TABLE users ADD COLUMN email_verified_at INTEGER").run();
    // Existing local accounts predate verification; preserve their QA access.
    await db.prepare("UPDATE users SET email_verified_at = created_at WHERE email_verified_at IS NULL").run();
  }

  const contentSeriesColumns = await db.prepare("PRAGMA table_info(content_series)").all<{ name: string }>();
  if (!contentSeriesColumns.results.some((column) => column.name === "search_text")) {
    await db.prepare("ALTER TABLE content_series ADD COLUMN search_text TEXT NOT NULL DEFAULT ''").run();
  }

  const outboxDefinition = await db.prepare("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'notification_outbox'").first<{ sql: string }>();
  if (outboxDefinition?.sql.includes("CHECK(kind IN") && !outboxDefinition.sql.includes("'new_episode'")) {
    await db.batch([
      db.prepare("DROP TABLE IF EXISTS notification_outbox_next"),
      db.prepare(`CREATE TABLE notification_outbox_next (
        id TEXT PRIMARY KEY NOT NULL,
        user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
        recipient TEXT NOT NULL,
        kind TEXT NOT NULL CHECK(kind IN ('verify_email','password_reset','security_notice','new_episode')),
        subject TEXT NOT NULL,
        body TEXT NOT NULL,
        action_url TEXT,
        dedupe_key TEXT,
        status TEXT NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','opened')),
        created_at INTEGER NOT NULL,
        opened_at INTEGER
      )`),
      db.prepare(`INSERT INTO notification_outbox_next
        (id, user_id, recipient, kind, subject, body, action_url, dedupe_key, status, created_at, opened_at)
        SELECT id, user_id, recipient, kind, subject, body, action_url, NULL, status, created_at, opened_at
        FROM notification_outbox`),
      db.prepare("DROP TABLE notification_outbox"),
      db.prepare("ALTER TABLE notification_outbox_next RENAME TO notification_outbox"),
    ]);
  } else {
    const outboxColumns = await db.prepare("PRAGMA table_info(notification_outbox)").all<{ name: string }>();
    if (!outboxColumns.results.some((column) => column.name === "dedupe_key")) {
      await db.prepare("ALTER TABLE notification_outbox ADD COLUMN dedupe_key TEXT").run();
    }
  }
  await db.batch([
    db.prepare("CREATE INDEX IF NOT EXISTS outbox_created_idx ON notification_outbox(created_at DESC)"),
    db.prepare("CREATE UNIQUE INDEX IF NOT EXISTS notification_outbox_dedupe_unique ON notification_outbox(dedupe_key)"),
  ]);

  const derivativeColumns = await db.prepare("PRAGMA table_info(media_derivative_jobs)").all<{ name: string }>();
  const derivativeColumnNames = new Set(derivativeColumns.results.map((column) => column.name));
  const missingDerivativeColumns = [
    ["dispatch_mode", "ALTER TABLE media_derivative_jobs ADD COLUMN dispatch_mode TEXT NOT NULL DEFAULT 'local_browser' CHECK(dispatch_mode IN ('local_browser','cloudflare_queue'))"],
    ["dispatch_status", "ALTER TABLE media_derivative_jobs ADD COLUMN dispatch_status TEXT NOT NULL DEFAULT 'local' CHECK(dispatch_status IN ('local','pending','sent','failed'))"],
    ["dispatch_attempts", "ALTER TABLE media_derivative_jobs ADD COLUMN dispatch_attempts INTEGER NOT NULL DEFAULT 0"],
    ["dispatch_error", "ALTER TABLE media_derivative_jobs ADD COLUMN dispatch_error TEXT"],
    ["dispatched_at", "ALTER TABLE media_derivative_jobs ADD COLUMN dispatched_at INTEGER"],
  ] as const;
  for (const [name, statement] of missingDerivativeColumns) {
    if (!derivativeColumnNames.has(name)) await db.prepare(statement).run();
  }
  await db.prepare("CREATE INDEX IF NOT EXISTS media_derivative_jobs_dispatch_idx ON media_derivative_jobs(dispatch_status, created_at)").run();
}

export async function writeAudit(userId: string | null, action: string, metadata?: Record<string, unknown>) {
  const db = await getDatabase();
  await db.prepare("INSERT INTO audit_events (id, user_id, action, metadata, created_at) VALUES (?, ?, ?, ?, ?)")
    .bind(crypto.randomUUID(), userId, action, metadata ? JSON.stringify(metadata) : null, Date.now())
    .run();
}
