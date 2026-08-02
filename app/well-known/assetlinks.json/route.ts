import {
  androidAssetLinksConfig,
  associatedDomainsUnavailable,
} from "../../lib/associated-domains";

// Digital Asset Links — App Links (bkz. apps/mobile/README.md "Gelecek
// adim" -> gerceklesen durum, production-bible.md yeni ADR). Android,
// `https://<domain>/.well-known/assetlinks.json`'i duz JSON olarak,
// `Content-Type: application/json` ile bekler (yonlendirme YOK, HTTP durum
// kodu 200 — istemciye gorunen URL budur); paket adi ve SHA-256 imza parmak
// izi/izleri buradan gelir. Bu dosya nokta ICERMEYEN `app/well-known/`
// altinda durur (bkz. `next.config.ts` rewrites() yorumu — build araci
// .-ile-baslayan dizinleri tarayamiyor); gercek
// `/.well-known/assetlinks.json` istegi oraya calisma zamaninda gorunmez
// bicimde yeniden yazilir.
//
// Gerekli degerler (ANDROID_PACKAGE_NAME, ANDROID_SHA256_FINGERPRINTS)
// ortamdan gelir; eksikse FAIL-CLOSED 503 doner — SAHTE paket adi/parmak
// izi ASLA uretilmez (bkz. `app/lib/associated-domains.ts`).
const READY_HEADERS = {
  "Content-Type": "application/json",
  "Cache-Control": "public, max-age=3600, stale-while-revalidate=86400",
} as const;

export async function GET() {
  const config = await androidAssetLinksConfig();
  if (!config) {
    return associatedDomainsUnavailable(
      "ANDROID_PACKAGE_NAME / ANDROID_SHA256_FINGERPRINTS",
    );
  }
  return Response.json(config, { headers: READY_HEADERS });
}
