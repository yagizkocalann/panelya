import { runtimeValue } from "./runtime-config";

// Universal Links (iOS) / App Links (Android) altyapisi (bkz.
// apps/mobile/README.md "Gelecek adim" -> gerceklesen durum,
// production-bible.md yeni ADR). Bu modul, `/.well-known/apple-app-site-association`
// ve `/.well-known/assetlinks.json` route handler'larinin paylastigi
// yapilandirma okuma mantigini tasir.
//
// FAIL-CLOSED: Production domain, Apple Team ID ve Android release SHA-256
// imza parmak izi bu depoda HENUZ YOK ve BURADA ASLA UYDURULMAZ. Gerekli
// ortam degiskenlerinden herhangi biri eksik/bos ise ilgili fonksiyon `null`
// doner; cagiran route handler bunu 503 (hizmet henuz yapilandirilmadi)
// olarak yanitlar — SAHTE/placeholder bir appID veya sertifika parmak izi
// ASLA uretilmez.

function trimmed(value: string) {
  return value.trim();
}

export type AppleAppSiteAssociation = {
  applinks: {
    apps: [];
    details: [{ appID: string; appIDs: [string]; paths: ["/*"] }];
  };
};

/**
 * `APPLE_TEAM_ID` ve `APPLE_BUNDLE_ID` ortam degiskenlerinden AASA govdesini
 * kurar. Apple'in appID sozdizimi `<TeamID>.<BundleID>` seklindedir (bkz.
 * Apple "Supporting associated domains" dokumani). Ikisi de doluysa `paths`
 * `/*` (tum path'ler) olarak ayarlanir — ayrintili host/path guvenligi
 * zaten Flutter tarafinda `UniversalLinkConfig` allowlist'i +
 * `mapWebPathToMobileRoute` ile saglanir (bkz. apps/mobile/lib/app/router/).
 */
export async function appleAppSiteAssociationConfig(): Promise<AppleAppSiteAssociation | null> {
  const [teamId, bundleId] = await Promise.all([
    runtimeValue("APPLE_TEAM_ID"),
    runtimeValue("APPLE_BUNDLE_ID"),
  ]);
  const trimmedTeamId = trimmed(teamId);
  const trimmedBundleId = trimmed(bundleId);
  if (!trimmedTeamId || !trimmedBundleId) return null;

  const appId = `${trimmedTeamId}.${trimmedBundleId}`;
  return {
    applinks: {
      apps: [],
      details: [{ appID: appId, appIDs: [appId], paths: ["/*"] }],
    },
  };
}

export type AndroidAssetLinks = Array<{
  relation: ["delegate_permission/common.handle_all_urls"];
  target: {
    namespace: "android_app";
    package_name: string;
    sha256_cert_fingerprints: string[];
  };
}>;

/**
 * `ANDROID_PACKAGE_NAME` ve `ANDROID_SHA256_FINGERPRINTS` (virgulle ayrilmis,
 * birden fazla imza parmak izi icin — orn. Play App Signing yukleme +
 * uygulama imzalama anahtari) ortam degiskenlerinden Digital Asset Links
 * govdesini kurar (bkz. Android "Verify Android App Links" dokumani).
 */
export async function androidAssetLinksConfig(): Promise<AndroidAssetLinks | null> {
  const [packageName, fingerprintsRaw] = await Promise.all([
    runtimeValue("ANDROID_PACKAGE_NAME"),
    runtimeValue("ANDROID_SHA256_FINGERPRINTS"),
  ]);
  const trimmedPackageName = trimmed(packageName);
  const fingerprints = fingerprintsRaw
    .split(",")
    .map((value) => value.trim())
    .filter((value) => value.length > 0);
  if (!trimmedPackageName || fingerprints.length === 0) return null;

  return [
    {
      relation: ["delegate_permission/common.handle_all_urls"],
      target: {
        namespace: "android_app",
        package_name: trimmedPackageName,
        sha256_cert_fingerprints: fingerprints,
      },
    },
  ];
}

export const ASSOCIATED_DOMAINS_UNAVAILABLE_HEADERS = {
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
} as const;

/**
 * Yapilandirma eksikken FAIL-CLOSED yanit (bkz. modul dokumani). 404 yerine
 * 503 kullanilir: dosyanin kendisi kavramsal olarak "var" ama bu ortamda
 * henuz sunulamiyor — bir istemcinin "hicbir zaman olmayacak" (404) ile
 * "henuz yapilandirilmadi" (503) durumunu ayirt edebilmesi icin.
 */
export function associatedDomainsUnavailable(missingEnvVarsHint: string) {
  return Response.json(
    {
      schemaVersion: "1.0",
      error: "service_unavailable",
      errorDescription: `Universal Links/App Links henuz yapilandirilmadi (${missingEnvVarsHint} eksik).`,
    },
    { status: 503, headers: ASSOCIATED_DOMAINS_UNAVAILABLE_HEADERS },
  );
}
