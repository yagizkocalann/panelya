import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { REQUIRED_D1_TABLES, prepareRecoveryBundle, sha256File, validateRecoveryBundle } from "../scripts/verify-recovery-bundle.mjs";

test("kurtarma envanteri Drizzle tablo semasiyla ayni kalir", async () => {
  const schema = await readFile(new URL("../db/schema.ts", import.meta.url), "utf8");
  const tableNames = [...schema.matchAll(/sqliteTable\("([a-z][a-z0-9_]*)"/g)].map((match) => match[1]).sort();
  assert.deepEqual(tableNames, REQUIRED_D1_TABLES);
});

async function makeBundle(mutator) {
  const directory = await mkdtemp(path.join(os.tmpdir(), "panelya-recovery-test-"));
  const database = `${REQUIRED_D1_TABLES.map((table) => `CREATE TABLE IF NOT EXISTS \"${table}\" (id TEXT);`).join("\n")}\n`;
  const sourceDigest = createHash("sha256").update("synthetic-source").digest("hex");
  const assetId = randomUUID();
  const manifest = {
    schemaVersion: "1.0",
    objectCount: 1,
    totalBytes: 16,
    entries: [{
      key: `media/panel/2026/${sourceDigest.slice(0, 16)}-${assetId}.webp`,
      kind: "source",
      sha256: sourceDigest,
      byteSize: 16,
      contentType: "image/webp",
      width: 1080,
      height: 1920,
    }],
  };
  const databasePath = path.join(directory, "database.sql");
  const manifestPath = path.join(directory, "media-manifest.json");
  await writeFile(databasePath, database, "utf8");
  await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
  const metadata = {
    schemaVersion: "1.0",
    createdAt: "2026-07-19T01:20:00.000Z",
    database: { file: "database.sql", sha256: await sha256File(databasePath), requiredTables: REQUIRED_D1_TABLES },
    media: { manifest: "media-manifest.json", sha256: await sha256File(manifestPath) },
  };
  if (mutator) await mutator({ directory, databasePath, manifestPath, manifest, metadata });
  await writeFile(path.join(directory, "recovery-metadata.json"), `${JSON.stringify(metadata, null, 2)}\n`, "utf8");
  return directory;
}

test("sentetik D1 ve R2 envanteri iceren kurtarma paketini dogrular", async (t) => {
  const directory = await makeBundle();
  t.after(() => rm(directory, { recursive: true, force: true }));
  const result = await validateRecoveryBundle(directory);
  assert.equal(result.database.requiredTableCount, REQUIRED_D1_TABLES.length);
  assert.equal(result.media.objectCount, 1);
  assert.equal(result.media.sha256Verified, true);
});

test("degistirilmis D1 exportunu uygulamadan once reddeder", async (t) => {
  const directory = await makeBundle(async ({ databasePath }) => {
    await writeFile(databasePath, "CREATE TABLE users (id TEXT);\n", "utf8");
  });
  t.after(() => rm(directory, { recursive: true, force: true }));
  await assert.rejects(validateRecoveryBundle(directory), /D1 exportu SHA-256 ozeti metadata ile uyusmuyor/);
});

test("anahtar ozeti icerikle uyusmayan medya manifestini reddeder", async (t) => {
  const directory = await makeBundle(async ({ manifestPath, manifest, metadata }) => {
    manifest.entries[0].sha256 = "0".repeat(64);
    await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
    metadata.media.sha256 = await sha256File(manifestPath);
  });
  t.after(() => rm(directory, { recursive: true, force: true }));
  await assert.rejects(validateRecoveryBundle(directory), /anahtar ozeti nesne SHA-256 ozetiyle uyusmuyor/);
});

test("paket koku disina cikan artifact yolunu semada reddeder", async (t) => {
  const directory = await makeBundle(async ({ metadata }) => {
    metadata.database.file = "../database.sql";
  });
  t.after(() => rm(directory, { recursive: true, force: true }));
  await assert.rejects(validateRecoveryBundle(directory), /recovery-metadata.json sema hatasi/);
});

test("SQL ve R2 manifestinden metadata dosyasini guvenli bicimde hazirlar", async (t) => {
  const directory = await makeBundle();
  t.after(() => rm(directory, { recursive: true, force: true }));
  await rm(path.join(directory, "recovery-metadata.json"));
  const result = await prepareRecoveryBundle(directory, "2026-07-19T02:00:00.000Z");
  assert.equal(result.database.sha256Verified, true);
  await assert.rejects(prepareRecoveryBundle(directory), /EEXIST/);
});
