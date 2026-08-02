import { access, readFile } from "node:fs/promises";
import process from "node:process";
import { pathToFileURL } from "node:url";

// Bu script gercek bir Xcode build/APNs kaydi CALISTIRMAZ — Simulator'da
// APNs token hic gelmedigi icin gercek cihaz DISINDA bu hicbir zaman canli
// dogrulanamaz (bkz. docs/mobile-web-handoff-findings.md #5). Yalniz statik
// proje dosyalarini (Info.plist, project.pbxproj, GoogleService-Info.plist
// VARLIGI) denetleyip iOS push kurulumunun hangi parcasinin depoda hazir,
// hangisinin bir insanin Apple Developer hesabi + Xcode + Firebase
// Console'da ELLE tamamlamasi gereken DIS bagimlilik oldugunu SECRET
// GOSTERMEDEN (deger degil, yalniz var/yok) raporlar.
//
// "ready" yalniz BLOKE EDICI kontrollerden hesaplanir; bilgilendirici
// (blocking: false) kontroller depoda bugun eksik olsa bile genel sonucu
// FAIL'e cevirmez — cunku bu proje su an yalniz alert-tabanli (gorunur)
// push kullaniyor, sessiz/content-available arka plan push'u DEGIL.

function check(id, ready, detail, { blocking = true } = {}) {
  return { id, status: ready ? "ready" : "missing", detail, blocking };
}

async function fileExists(path) {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

function hasArrayStringValue(plistXml, arrayKey, value) {
  const escapedKey = arrayKey.replace(/[.*+?^${}()|[\]\\]/gu, "\\$&");
  const blockMatch = plistXml.match(
    new RegExp(`<key>${escapedKey}</key>\\s*<array>([\\s\\S]*?)</array>`, "u"),
  );
  if (!blockMatch) return false;
  return new RegExp(`<string>${value}</string>`, "u").test(blockMatch[1]);
}

/**
 * iOS push readiness'ini statik dosya denetimiyle raporlar. Secret/deger
 * ASLA dondurmez — yalniz her kontrolun var/yok durumunu ve neden onemli
 * olduguna dair sabit bir aciklama dondurur.
 */
export async function validateIosPushReadiness({ mobileRoot }) {
  const infoPlistPath = new URL("ios/Runner/Info.plist", mobileRoot);
  const entitlementsPath = new URL("ios/Runner/Runner.entitlements", mobileRoot);
  const googleServicePlistPath = new URL(
    "ios/Runner/GoogleService-Info.plist",
    mobileRoot,
  );
  const pbxprojPath = new URL(
    "ios/Runner.xcodeproj/project.pbxproj",
    mobileRoot,
  );

  const [infoPlistXml, pbxproj, entitlementsXml, googleServiceExists] =
    await Promise.all([
      readFile(infoPlistPath, "utf8"),
      readFile(pbxprojPath, "utf8"),
      readFile(entitlementsPath, "utf8").catch(() => null),
      fileExists(googleServicePlistPath),
    ]);

  // `Runner.entitlements` artik Universal Links (associated-domains) icin de
  // olusturulabiliyor (bkz. Runner/Runner.entitlements yorumu); bu yuzden
  // SADECE DOSYA VARLIGI push icin yeterli bir sinyal DEGIL — bir onceki
  // surumde dosya hic yoktu, artik varsa bile icinde 'aps-environment'
  // anahtari OLMAYABILIR (orn. yalniz associated-domains icin olusturulmus
  // bir dosya). Push readiness'i yanlislikla "ready" GOSTERMEMEK icin
  // gercek anahtarin VARLIGI da denetlenir.
  const hasApsEnvironmentKey =
    entitlementsXml !== null && /<key>aps-environment<\/key>/u.test(entitlementsXml);

  const checks = [
    check(
      "url-scheme",
      hasArrayStringValue(infoPlistXml, "CFBundleURLSchemes", "panelya"),
      "Info.plist CFBundleURLTypes/CFBundleURLSchemes icinde 'panelya' kayitli olmali; bildirime dokununca deep-link'in acilabilmesi bu kayda baglidir.",
    ),
    check(
      "background-remote-notification",
      hasArrayStringValue(infoPlistXml, "UIBackgroundModes", "remote-notification"),
      "Info.plist UIBackgroundModes icinde 'remote-notification' yok. BILGILENDIRME: gorunur (alert) push'u ENGELLEMEZ — bu proje v1'de yalniz alert-tabanli push kullaniyor, sessiz/content-available arka plan push'u degil. Yalniz ileride sessiz push ile arka plan calismasi eklenirse gerekli olur.",
      { blocking: false },
    ),
    check(
      "entitlements-file",
      hasApsEnvironmentKey,
      "ios/Runner/Runner.entitlements bulunamadi VEYA icinde 'aps-environment' anahtari yok (dosya var olsa bile — orn. yalniz Universal Links associated-domains icin olusturulmus bir entitlements dosyasi bu anahtari icermez). Push Notifications capability icin Xcode'da 'Signing & Capabilities' -> 'Push Notifications' eklenip/onaylanip GECERLI bir Apple Developer takimi + provisioning profile ile guncellenmelidir. Bu depo/script tarafindan OTOMATIK olusturulamaz.",
    ),
    check(
      "entitlements-wired-to-target",
      /CODE_SIGN_ENTITLEMENTS/u.test(pbxproj),
      "project.pbxproj icinde CODE_SIGN_ENTITLEMENTS build ayari yok — entitlements dosyasi Xcode'da olusturulunca otomatik eklenir; elle duzenlenmemeli.",
    ),
    check(
      "google-service-plist-present",
      googleServiceExists,
      "ios/Runner/GoogleService-Info.plist bulunamadi (bkz. docs/mobile-firebase-config.md). Yalniz DOSYA VARLIGI kontrol edilir; icerik okunmaz/yazdirilmaz.",
    ),
  ];

  const blockingChecks = checks.filter((item) => item.blocking);

  return {
    ready: blockingChecks.every((item) => item.status === "ready"),
    checks,
    missingBlocking: blockingChecks
      .filter((item) => item.status === "missing")
      .map((item) => item.id),
  };
}

/**
 * Statik dosya denetimiyle ASLA verify edilemeyen, bir insanin Apple
 * Developer hesabi + Xcode + Firebase Console'da elle tamamlamasi gereken
 * DIS bagimliliklar (bkz. docs/mobile-web-handoff-findings.md #5). Yalniz
 * ADLAR listelenir, deger yoktur ve script bunlarin VARLIGINI kontrol
 * ETMEZ (edemez).
 */
export const IOS_PUSH_EXTERNAL_DEPENDENCIES = [
  "Apple Developer Program uyeligi (ucretli, aktif)",
  "Xcode 'Signing & Capabilities' -> 'Push Notifications' capability (Runner.entitlements'i uretir)",
  "Push Notifications destekleyen gecerli bir provisioning profile (Development veya Distribution, DEVELOPMENT_TEAM ile eslesen)",
  "APNs Auth Key (.p8) + Key ID + Team ID -> Firebase Console 'Cloud Messaging' -> 'Apple app configuration'a yuklu olmali",
  "Fiziksel iPhone (Simulator APNs token ALAMAZ, bkz. docs/mobile-web-handoff-findings.md #5)",
  "Sunucu tarafi gonderim degiskenleri FCM_PROJECT_ID / FCM_CLIENT_EMAIL / FCM_PRIVATE_KEY (bkz. scripts/verify-production-deployment-readiness.mjs — bu script onlari ZATEN denetliyor, burada TEKRAR EDILMEZ)",
];

function defaultMobileRoot() {
  return new URL("../apps/mobile/", import.meta.url);
}

async function main() {
  const mobileRoot = defaultMobileRoot();
  let result;
  try {
    result = await validateIosPushReadiness({ mobileRoot });
  } catch (error) {
    process.stdout.write(
      `iOS push canli ön kontrolü: beklenen proje dosyalarından biri okunamadı (${error.code ?? "hata"}).\n`,
    );
    process.exitCode = 1;
    return;
  }

  process.stdout.write("iOS push canlı ön kontrolü (statik dosya denetimi)\n");
  for (const item of result.checks) {
    // `detail` BASARISIZLIK aciklamasidir; gecen bir kontrolde basilirsa
    // kendisiyle celisen ("OK ... bulunamadi") bir satir olusur. Bu yuzden
    // yalnizca gecmeyen kontroller icin yazdirilir.
    if (item.status === "ready") {
      process.stdout.write(`OK ${item.id}\n`);
      continue;
    }
    const marker = item.blocking ? "EKSİK" : "BİLGİ";
    process.stdout.write(`${marker} ${item.id}: ${item.detail}\n`);
  }

  process.stdout.write(
    "\nStatik olarak DOĞRULANAMAYAN dış bağımlılıklar (yalnız adlar, script bunları kontrol EDEMEZ):\n",
  );
  for (const name of IOS_PUSH_EXTERNAL_DEPENDENCIES) {
    process.stdout.write(`- ${name}\n`);
  }

  process.stdout.write(
    result.ready
      ? "\nSONUÇ: Depodaki statik iOS push ön koşulları hazır. Canlı doğrulama YİNE DE yalnız fiziksel cihazda yapılabilir.\n"
      : `\nSONUÇ: Eksik bloke edici kontroller: ${result.missingBlocking.join(", ")}. Bunlar giderilmeden gerçek cihazda APNs kaydı beklenmemelidir.\n`,
  );
  process.exitCode = result.ready ? 0 : 1;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  await main();
}
