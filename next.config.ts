import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Universal Links (iOS) / App Links (Android) altyapisi (bkz.
  // apps/mobile/README.md "Gelecek adim" -> gerceklesen durum,
  // production-bible.md yeni ADR): Apple/Android sozlesmesi bu iki dosyanin
  // TAM OLARAK `/.well-known/<isim>` altinda, NOKTA ILE BASLAYAN bir dizin
  // segmentiyle sunulmasini gerektirir (bkz. Apple "Supporting associated
  // domains", Android "Verify Android App Links" dokumanlari) — yonlendirme
  // (redirect) KABUL EDILMEZ, dogrudan 200 + JSON govde beklenir.
  //
  // Bu depodaki build araci (vinext), dosya tabanli rota tarayicisinda
  // NOKTA ILE BASLAYAN dizin adlarini (`.well-known`) glob taramasindan
  // DISLAR (bkz. node_modules/vinext/dist/routing/app-route-graph.js,
  // `buildAppRouteGraph`'in `scanWithExtensions("**/route", ...)` cagrisi —
  // Node'un `fs/promises.glob`'u varsayilan olarak dot-dizinlere GIRMEZ);
  // bu yuzden gercek route handler'lari nokta ICERMEYEN `app/well-known/`
  // altinda tutulur (bkz. `app/well-known/apple-app-site-association/route.ts`,
  // `app/well-known/assetlinks.json/route.ts`) ve gelen `/.well-known/*`
  // istegi burada, calisma zamaninda (build-time dizin taramasindan
  // BAGIMSIZ calisan bir rewrite kurali ile) sessizce `/well-known/*`e
  // yeniden yazilir. Rewrite, tarayiciya/istemciye GORUNMEZ (200, ayni URL);
  // yalnizca dahili dosya eslemesini degistirir.
  async rewrites() {
    return [
      {
        source: "/.well-known/apple-app-site-association",
        destination: "/well-known/apple-app-site-association",
      },
      {
        source: "/.well-known/assetlinks.json",
        destination: "/well-known/assetlinks.json",
      },
    ];
  },
};

export default nextConfig;
