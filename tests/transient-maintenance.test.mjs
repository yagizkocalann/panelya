import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), "utf8");

test("transient maintenance only purges established expiry boundaries", async () => {
  const source = await read("app/lib/transient-data-maintenance.ts");
  const expected = [
    "sessions WHERE expires_at <= ? OR idle_expires_at <= ?",
    "account_tokens WHERE expires_at <= ?",
    "account_reauthentication_requests WHERE expires_at <= ?",
    "account_reauthentication_tokens WHERE expires_at <= ?",
    "preview_tokens WHERE expires_at <= ?",
    "rate_limit_buckets WHERE reset_at <= ?",
  ];
  for (const boundary of expected) assert.match(source, new RegExp(boundary.replace(/[?]/g, "\\?")));
  assert.match(source, /purgeExpiredOutbox\(now, db\)/);
  for (const excluded of ["audit_events", "contact_messages", "copyright_notices", "admin_invitations", "account_deletion_requests", "reviews", "media_derivative_jobs"]) {
    assert.doesNotMatch(source, new RegExp(`DELETE FROM ${excluded}`));
  }
});

test("scheduled maintenance uses D1, a fixed UTC cron and aggregate-only logs", async () => {
  const [worker, config] = await Promise.all([read("worker/index.ts"), read("vite.config.ts")]);
  assert.match(config, /crons:\s*\["17 3 \* \* \*"\]/);
  assert.match(worker, /async scheduled\(controller: ScheduledController, env: Env, ctx: ExecutionContext\)/);
  assert.match(worker, /purgeExpiredTransientData\(controller\.scheduledTime, env\.DB\)/);
  assert.match(worker, /policyVersion: result\.policyVersion/);
  assert.match(worker, /deletedCount: result\.total/);
  assert.doesNotMatch(worker, /tokenHash|userId|email|recipient/);
});

test("Studio fallback is host, auth, freshness, origin and rate-limit protected", async () => {
  const [route, page, audit] = await Promise.all([
    read("app/api/admin/maintenance/transient-data/route.ts"),
    read("app/studio/qa/page.tsx"),
    read("app/studio/audit/page.tsx"),
  ]);
  assert.match(route, /isStudioRequest\(request\)/);
  assert.match(route, /assertSameOrigin\(request\)/);
  assert.match(route, /actor\.role !== "admin"/);
  assert.match(route, /hasRecentAuthentication\(\)/);
  assert.match(route, /consumeRateLimit\("admin-transient-maintenance"/);
  assert.match(route, /admin\.transient_data_purged/);
  assert.match(page, /Süresi dolan geçici kayıtları temizle/);
  assert.match(audit, /admin\.transient_data_purged/);
});

test("expiry scans are indexed in schema, migration and local bootstrap", async () => {
  const [schema, migration, bootstrap] = await Promise.all([
    read("db/schema.ts"),
    read("drizzle/0019_romantic_miek.sql"),
    read("app/lib/database.ts"),
  ]);
  for (const indexName of ["account_tokens_expiry_idx", "rate_limit_buckets_reset_idx"]) {
    assert.match(schema, new RegExp(indexName));
    assert.match(migration, new RegExp(indexName));
    assert.match(bootstrap, new RegExp(indexName));
  }
});
