import type { MetadataRoute } from "next";
import { listPublishedSeriesForSitemap } from "./lib/content-repository";
import { publicSiteUrlForCurrentRequest } from "./lib/server-site-origins";

const staticRoutes = [
  { path: "/", changeFrequency: "daily", priority: 1 },
  { path: "/catalog", changeFrequency: "daily", priority: 0.9 },
  { path: "/new-series", changeFrequency: "daily", priority: 0.9 },
  { path: "/updates", changeFrequency: "daily", priority: 0.9 },
  { path: "/about", changeFrequency: "monthly", priority: 0.5 },
  { path: "/contact", changeFrequency: "yearly", priority: 0.3 },
  { path: "/copyright", changeFrequency: "yearly", priority: 0.3 },
  { path: "/creators", changeFrequency: "monthly", priority: 0.5 },
  { path: "/privacy", changeFrequency: "yearly", priority: 0.3 },
  { path: "/production-journal", changeFrequency: "monthly", priority: 0.5 },
  { path: "/publishing-principles", changeFrequency: "monthly", priority: 0.5 },
  { path: "/terms", changeFrequency: "yearly", priority: 0.3 },
] as const;

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const [publicOrigin, publishedSeries] = await Promise.all([
    publicSiteUrlForCurrentRequest("/"),
    listPublishedSeriesForSitemap(),
  ]);
  const absoluteUrl = (path: string) => new URL(path, publicOrigin).toString();

  return [
    ...staticRoutes.map((route) => ({
      url: absoluteUrl(route.path),
      changeFrequency: route.changeFrequency,
      priority: route.priority,
    })),
    ...publishedSeries.map((series) => ({
      url: absoluteUrl(`/${series.slug}`),
      lastModified: series.lastModified ? new Date(series.lastModified) : undefined,
      changeFrequency: "weekly" as const,
      priority: 0.8,
    })),
  ];
}
