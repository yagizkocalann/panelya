import {
  appleAppSiteAssociationConfig,
  associatedDomainsUnavailable,
} from "../../lib/associated-domains";

// Apple App Site Association (AASA) — Universal Links (bkz.
// apps/mobile/README.md "Gelecek adim" -> gerceklesen durum,
// production-bible.md yeni ADR). Apple, `https://<domain>/.well-known/apple-app-site-association`
// adresini IMZASIZ duz JSON olarak, `Content-Type: application/json` ile
// bekler (yonlendirme YOK, HTTP durum kodu 200 — istemciye gorunen URL
// budur). Bu dosya nokta ICERMEYEN `app/well-known/` altinda durur (bkz.
// `next.config.ts` rewrites() yorumu — build araci .-ile-baslayan dizinleri
// tarayamiyor); gercek `/.well-known/apple-app-site-association` istegi
// oraya calisma zamaninda gorunmez bicimde yeniden yazilir.
//
// Gerekli degerler (APPLE_TEAM_ID, APPLE_BUNDLE_ID) ortamdan gelir; eksikse
// FAIL-CLOSED 503 doner — SAHTE appID/domain ASLA uretilmez (bkz.
// `app/lib/associated-domains.ts`).
const READY_HEADERS = {
  "Content-Type": "application/json",
  // Apple'in kendi CDN'i AASA'yi zaten yogun bicimde onbelleklediginden
  // (bkz. Apple "Supporting associated domains" dokumani) burada kisa bir
  // TTL + stale-while-revalidate yeterlidir; asiri uzun bir max-age,
  // Team ID/appID rotasyonu gibi nadir bir degisikligi gereksiz uzun sure
  // gecikmeye zorlar.
  "Cache-Control": "public, max-age=3600, stale-while-revalidate=86400",
} as const;

export async function GET() {
  const config = await appleAppSiteAssociationConfig();
  if (!config) {
    return associatedDomainsUnavailable("APPLE_TEAM_ID / APPLE_BUNDLE_ID");
  }
  return Response.json(config, { headers: READY_HEADERS });
}
