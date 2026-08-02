import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { extname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { gzipSync } from "node:zlib";

const root = new URL("../", import.meta.url);
const config = JSON.parse(readFileSync(new URL("../docs/performance-budgets.json", import.meta.url), "utf8"));

function filesWithExtension(directory, extension) {
  const directoryPath = fileURLToPath(directory);
  return readdirSync(directory)
    .filter((name) => extname(name) === extension)
    .map((name) => join(directoryPath, name));
}

function total(files, sizeOf) {
  return files.reduce((sum, file) => sum + sizeOf(file), 0);
}

function trackedPublicMedia() {
  const output = execFileSync("git", ["ls-files", "-z", "public"], {
    cwd: root,
    encoding: "utf8",
  });
  return output
    .split("\0")
    .filter((file) => /\.(?:avif|jpe?g|png|webp)$/iu.test(file) && existsSync(new URL(`../${file}`, import.meta.url)))
    .map((file) => new URL(`../${file}`, import.meta.url));
}

export function checkPerformanceBudgets() {
  const assetDirectory = new URL("../dist/client/assets/", import.meta.url);
  const serverEntry = new URL("../dist/server/index.js", import.meta.url);
  if (!existsSync(assetDirectory) || !existsSync(serverEntry)) {
    throw new Error("Build çıktısı bulunamadı. Önce `npm run build` çalıştır.");
  }

  const jsFiles = filesWithExtension(assetDirectory, ".js");
  const cssFiles = filesWithExtension(assetDirectory, ".css");
  const rawSize = (file) => statSync(file).size;
  const gzipSize = (file) => gzipSync(readFileSync(file)).length;
  const largest = (files) => files.length ? Math.max(...files.map(rawSize)) : 0;

  const publicMedia = trackedPublicMedia();
  const report = {
    clientJavaScript: {
      files: jsFiles.length,
      totalGzipBytes: total(jsFiles, gzipSize),
      largestRawBytes: largest(jsFiles),
    },
    clientCss: {
      files: cssFiles.length,
      totalGzipBytes: total(cssFiles, gzipSize),
      largestRawBytes: largest(cssFiles),
    },
    server: { entryRawBytes: rawSize(serverEntry) },
    trackedPublicMedia: {
      files: publicMedia.length,
      largestRawBytes: largest(publicMedia),
    },
  };

  const violations = [];
  if (report.clientJavaScript.totalGzipBytes > config.clientJavaScript.maxTotalGzipBytes) violations.push("Toplam gzip JavaScript bütçeyi aştı.");
  if (report.clientJavaScript.largestRawBytes > config.clientJavaScript.maxSingleRawBytes) violations.push("Tek JavaScript chunk bütçeyi aştı.");
  if (report.clientCss.totalGzipBytes > config.clientCss.maxTotalGzipBytes) violations.push("Toplam gzip CSS bütçeyi aştı.");
  if (report.clientCss.largestRawBytes > config.clientCss.maxSingleRawBytes) violations.push("Tek CSS dosyası bütçeyi aştı.");
  if (report.server.entryRawBytes > config.server.maxEntryRawBytes) violations.push("Worker server entry bütçeyi aştı.");
  if (report.trackedPublicMedia.largestRawBytes > config.trackedPublicMedia.maxSingleBytes) violations.push("Git ile izlenen tek public medya bütçeyi aştı.");

  if (violations.length) {
    throw new Error(`${violations.join(" ")}\n${JSON.stringify(report, null, 2)}`);
  }
  return report;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  const report = checkPerformanceBudgets();
  console.log("Performans bütçeleri geçildi.");
  console.log(JSON.stringify(report, null, 2));
}
