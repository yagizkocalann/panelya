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
      kind TEXT NOT NULL CHECK(kind IN ('verify_email','password_reset','security_notice')),
      subject TEXT NOT NULL,
      body TEXT NOT NULL,
      action_url TEXT,
      status TEXT NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','opened')),
      created_at INTEGER NOT NULL,
      opened_at INTEGER
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
    db.prepare(`CREATE TABLE IF NOT EXISTS content_series (
      slug TEXT PRIMARY KEY NOT NULL,
      title TEXT NOT NULL,
      eyebrow TEXT NOT NULL,
      creator TEXT NOT NULL,
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
    db.prepare("CREATE INDEX IF NOT EXISTS account_tokens_user_idx ON account_tokens(user_id, purpose, created_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS account_tokens_expiry_idx ON account_tokens(expires_at)"),
    db.prepare("CREATE INDEX IF NOT EXISTS outbox_created_idx ON notification_outbox(created_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS reviews_series_idx ON reviews(series_slug, status, updated_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS review_reports_status_idx ON review_reports(status, created_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS review_reports_review_idx ON review_reports(review_id, status)"),
    db.prepare("CREATE INDEX IF NOT EXISTS content_series_publication_idx ON content_series(publication_status, is_featured DESC, updated_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS content_episodes_series_idx ON content_episodes(series_slug, publication_status, number DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS media_assets_series_idx ON media_assets(series_slug, episode_slug, created_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS preview_tokens_scope_idx ON preview_tokens(series_slug, episode_slug, expires_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS preview_tokens_expiry_idx ON preview_tokens(expires_at)"),
  ]);

  const userColumns = await db.prepare("PRAGMA table_info(users)").all<{ name: string }>();
  if (!userColumns.results.some((column) => column.name === "email_verified_at")) {
    await db.prepare("ALTER TABLE users ADD COLUMN email_verified_at INTEGER").run();
    // Existing local accounts predate verification; preserve their QA access.
    await db.prepare("UPDATE users SET email_verified_at = created_at WHERE email_verified_at IS NULL").run();
  }
}

export async function writeAudit(userId: string | null, action: string, metadata?: Record<string, unknown>) {
  const db = await getDatabase();
  await db.prepare("INSERT INTO audit_events (id, user_id, action, metadata, created_at) VALUES (?, ?, ?, ?, ?)")
    .bind(crypto.randomUUID(), userId, action, metadata ? JSON.stringify(metadata) : null, Date.now())
    .run();
}
