import type { MetadataRoute } from "next";
import { currentRequestIsStudio, publicSiteUrlForCurrentRequest } from "./lib/server-site-origins";

export default async function robots(): Promise<MetadataRoute.Robots> {
  if (await currentRequestIsStudio()) {
    return { rules: { userAgent: "*", disallow: "/" } };
  }

  const publicOrigin = await publicSiteUrlForCurrentRequest("/");
  return {
    rules: {
      userAgent: "*",
      allow: "/",
      disallow: [
        "/api/",
        "/account",
        "/accept-admin-invite",
        "/bootstrap-admin",
        "/forgot-password",
        "/library",
        "/login",
        "/preview/",
        "/register",
        "/reset-password",
        "/studio",
        "/verify-email",
      ],
    },
    sitemap: new URL("/sitemap.xml", publicOrigin).toString(),
    host: new URL(publicOrigin).origin,
  };
}
