import { createHash } from "node:crypto";
import { createReadStream } from "node:fs";
import { lstat, readFile, realpath, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import Ajv2020 from "ajv/dist/2020.js";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const schemaPath = path.resolve(scriptDirectory, "../docs/recovery-bundle.schema.json");
const MAX_JSON_BYTES = 100 * 1024 * 1024;

export const REQUIRED_D1_TABLES = Object.freeze([
  "account_tokens",
  "admin_invitations",
  "audit_events",
  "contact_messages",
  "content_episodes",
  "content_series",
  "library_items",
  "media_assets",
  "media_derivative_jobs",
  "media_variants",
  "notification_outbox",
  "preview_tokens",
  "rate_limit_buckets",
  "reading_progress",
  "review_reports",
  "reviews",
  "series_subscriptions",
  "sessions",
  "users",
]);

function formatAjvErrors(errors = []) {
  return errors.map((error) => `${error.instancePath || "/"} ${error.message}`).join("; ");
}

async function loadValidators() {
  const schema = JSON.parse(await readFile(schemaPath, "utf8"));
  const ajv = new Ajv2020({ allErrors: true, strict: true });
  ajv.addSchema(schema);
  return {
    metadata: ajv.compile({ $ref: `${schema.$id}#/$defs/recoveryMetadata` }),
    manifest: ajv.compile({ $ref: `${schema.$id}#/$defs/mediaManifest` }),
  };
}

async function resolveSafeFile(bundleRealPath, relativeName, label) {
  if (path.basename(relativeName) !== relativeName) {
    throw new Error(`${label} yalnizca paket kokundeki bir dosya adi olmali.`);
  }
  const candidate = path.resolve(bundleRealPath, relativeName);
  if (path.dirname(candidate) !== bundleRealPath) {
    throw new Error(`${label} paket kokunun disina cikamaz.`);
  }
  const stats = await lstat(candidate);
  if (!stats.isFile() || stats.isSymbolicLink()) {
    throw new Error(`${label} normal bir dosya olmali; sembolik bag kabul edilmez.`);
  }
  const resolved = await realpath(candidate);
  if (path.dirname(resolved) !== bundleRealPath) {
    throw new Error(`${label} paket kokunun disina cozumleniyor.`);
  }
  return { path: resolved, size: stats.size };
}

async function readJsonFile(file, label) {
  if (file.size > MAX_JSON_BYTES) throw new Error(`${label} 100 MiB sinirini asiyor.`);
  try {
    return JSON.parse(await readFile(file.path, "utf8"));
  } catch {
    throw new Error(`${label} gecerli JSON degil.`);
  }
}

export async function sha256File(filePath) {
  const hash = createHash("sha256");
  for await (const chunk of createReadStream(filePath)) hash.update(chunk);
  return hash.digest("hex");
}

async function inspectD1Export(filePath) {
  const hash = createHash("sha256");
  const tableNames = new Set();
  const decoder = new TextDecoder();
  let carry = "";
  const tablePattern = /CREATE\s+TABLE(?:\s+IF\s+NOT\s+EXISTS)?\s+(?:"([^"]+)"|`([^`]+)`|\[([^\]]+)\]|([A-Za-z_][A-Za-z0-9_]*))/gi;

  for await (const chunk of createReadStream(filePath)) {
    hash.update(chunk);
    const text = carry + decoder.decode(chunk, { stream: true });
    for (const match of text.matchAll(tablePattern)) tableNames.add(match[1] ?? match[2] ?? match[3] ?? match[4]);
    carry = text.slice(-512);
  }
  const finalText = carry + decoder.decode();
  for (const match of finalText.matchAll(tablePattern)) tableNames.add(match[1] ?? match[2] ?? match[3] ?? match[4]);
  return { sha256: hash.digest("hex"), tableNames };
}

function assertCanonicalTables(tables) {
  const supplied = [...tables].sort();
  if (JSON.stringify(supplied) !== JSON.stringify(REQUIRED_D1_TABLES)) {
    throw new Error("recovery-metadata.json requiredTables listesi uygulamanin kanonik D1 tablo envanteriyle ayni degil.");
  }
}

function assertManifestSemantics(manifest) {
  const keys = new Set();
  let totalBytes = 0;
  for (const entry of manifest.entries) {
    if (keys.has(entry.key)) throw new Error("media-manifest.json ayni nesne anahtarini birden fazla kez iceriyor.");
    keys.add(entry.key);
    totalBytes += entry.byteSize;

    const sourcePattern = /^media\/(?:cover|panel)\/\d{4}\/[0-9a-f]{16}-[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(?:jpg|png|webp)$/;
    const derivativePattern = /^media\/derivatives\/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\/(?:480|768|1200)w-[0-9a-f]{16}\.webp$/;
    const expectedPattern = entry.kind === "source" ? sourcePattern : derivativePattern;
    if (!expectedPattern.test(entry.key)) throw new Error(`media-manifest.json ${entry.kind} anahtar bicimi gecersiz.`);

    const keyDigest = entry.kind === "source"
      ? path.basename(entry.key).slice(0, 16)
      : path.basename(entry.key).match(/w-([0-9a-f]{16})\.webp$/)?.[1];
    if (keyDigest !== entry.sha256.slice(0, 16)) throw new Error("media-manifest.json anahtar ozeti nesne SHA-256 ozetiyle uyusmuyor.");
    if (entry.kind === "derivative" && (entry.contentType !== "image/webp" || entry.key.includes(`/${entry.width}w-`) === false)) {
      throw new Error("Turetilmis medya kaydi WebP olmali ve anahtar genisligi manifest ile ayni olmali.");
    }
  }
  if (manifest.objectCount !== manifest.entries.length || manifest.totalBytes !== totalBytes) {
    throw new Error("media-manifest.json nesne sayisi veya toplam byte degeri entries ile uyusmuyor.");
  }
}

export async function validateRecoveryBundle(bundleDirectory) {
  const bundleStats = await lstat(bundleDirectory);
  if (!bundleStats.isDirectory() || bundleStats.isSymbolicLink()) throw new Error("Kurtarma paketi normal bir dizin olmali.");
  const bundleRealPath = await realpath(bundleDirectory);
  const metadataFile = await resolveSafeFile(bundleRealPath, "recovery-metadata.json", "recovery-metadata.json");
  const metadata = await readJsonFile(metadataFile, "recovery-metadata.json");
  const validators = await loadValidators();
  if (!validators.metadata(metadata)) throw new Error(`recovery-metadata.json sema hatasi: ${formatAjvErrors(validators.metadata.errors)}`);
  assertCanonicalTables(metadata.database.requiredTables);

  const databaseFile = await resolveSafeFile(bundleRealPath, metadata.database.file, "D1 exportu");
  const manifestFile = await resolveSafeFile(bundleRealPath, metadata.media.manifest, "R2 manifesti");
  const manifest = await readJsonFile(manifestFile, "media-manifest.json");
  if (!validators.manifest(manifest)) throw new Error(`media-manifest.json sema hatasi: ${formatAjvErrors(validators.manifest.errors)}`);
  assertManifestSemantics(manifest);

  const [databaseInspection, manifestHash] = await Promise.all([
    inspectD1Export(databaseFile.path),
    sha256File(manifestFile.path),
  ]);
  if (databaseInspection.sha256 !== metadata.database.sha256) throw new Error("D1 exportu SHA-256 ozeti metadata ile uyusmuyor.");
  if (manifestHash !== metadata.media.sha256) throw new Error("R2 manifesti SHA-256 ozeti metadata ile uyusmuyor.");
  const missingTables = REQUIRED_D1_TABLES.filter((table) => !databaseInspection.tableNames.has(table));
  if (missingTables.length > 0) throw new Error(`D1 exportu ${missingTables.length} zorunlu tablo tanimini icermiyor.`);

  return {
    schemaVersion: metadata.schemaVersion,
    createdAt: metadata.createdAt,
    database: { sha256Verified: true, requiredTableCount: REQUIRED_D1_TABLES.length },
    media: { sha256Verified: true, objectCount: manifest.objectCount, totalBytes: manifest.totalBytes },
  };
}

export async function prepareRecoveryBundle(bundleDirectory, createdAt = new Date().toISOString()) {
  const bundleStats = await lstat(bundleDirectory);
  if (!bundleStats.isDirectory() || bundleStats.isSymbolicLink()) throw new Error("Kurtarma paketi normal bir dizin olmali.");
  const bundleRealPath = await realpath(bundleDirectory);
  const databaseFile = await resolveSafeFile(bundleRealPath, "database.sql", "D1 exportu");
  const manifestFile = await resolveSafeFile(bundleRealPath, "media-manifest.json", "R2 manifesti");
  const manifest = await readJsonFile(manifestFile, "media-manifest.json");
  const validators = await loadValidators();
  if (!validators.manifest(manifest)) throw new Error(`media-manifest.json sema hatasi: ${formatAjvErrors(validators.manifest.errors)}`);
  assertManifestSemantics(manifest);
  const [databaseInspection, manifestHash] = await Promise.all([
    inspectD1Export(databaseFile.path),
    sha256File(manifestFile.path),
  ]);
  const missingTables = REQUIRED_D1_TABLES.filter((table) => !databaseInspection.tableNames.has(table));
  if (missingTables.length > 0) throw new Error(`D1 exportu ${missingTables.length} zorunlu tablo tanimini icermiyor.`);

  const metadata = {
    schemaVersion: "1.0",
    createdAt,
    database: { file: "database.sql", sha256: databaseInspection.sha256, requiredTables: REQUIRED_D1_TABLES },
    media: { manifest: "media-manifest.json", sha256: manifestHash },
  };
  if (!validators.metadata(metadata)) throw new Error(`Olusturulan metadata sema hatasi: ${formatAjvErrors(validators.metadata.errors)}`);
  await writeFile(path.join(bundleRealPath, "recovery-metadata.json"), `${JSON.stringify(metadata, null, 2)}\n`, { encoding: "utf8", flag: "wx" });
  return validateRecoveryBundle(bundleRealPath);
}

async function runCli() {
  const prepare = process.argv[2] === "--prepare";
  const bundleDirectory = process.argv[prepare ? 3 : 2];
  const expectedLength = prepare ? 4 : 3;
  if (!bundleDirectory || process.argv.length !== expectedLength) {
    throw new Error("Kullanim: npm run recovery:verify -- <paket-dizini> veya npm run recovery:prepare -- <paket-dizini>");
  }
  const result = prepare
    ? await prepareRecoveryBundle(path.resolve(bundleDirectory))
    : await validateRecoveryBundle(path.resolve(bundleDirectory));
  process.stdout.write(`Kurtarma paketi ${prepare ? "hazirlandi ve dogrulandi" : "dogrulandi"}: ${result.database.requiredTableCount} D1 tablosu, ${result.media.objectCount} R2 nesnesi, ${result.media.totalBytes} byte.\n`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  runCli().catch((error) => {
    process.stderr.write(`Kurtarma paketi gecersiz: ${error instanceof Error ? error.message : "bilinmeyen hata"}\n`);
    process.exitCode = 1;
  });
}
