import { headers } from "next/headers";
import { publicSiteOrigin } from "./site-origins";

export async function publicSiteUrlForCurrentRequest(path = "/") {
  const requestHeaders = await headers();
  const host = requestHeaders.get("x-forwarded-host")?.split(",")[0]?.trim() || requestHeaders.get("host") || "studio.localhost:3000";
  const protocol = requestHeaders.get("x-forwarded-proto")?.split(",")[0]?.trim() || (host.includes("localhost") ? "http" : "https");
  const request = new Request(`${protocol}://${host}/`);
  return new URL(path, `${publicSiteOrigin(request)}/`).toString();
}
