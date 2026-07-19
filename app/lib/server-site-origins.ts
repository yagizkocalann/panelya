import { headers } from "next/headers";
import { isLocalQaRequest, isStudioRequest, publicSiteOrigin } from "./site-origins";

export async function requestForCurrentHost() {
  const requestHeaders = await headers();
  const host = requestHeaders.get("x-forwarded-host")?.split(",")[0]?.trim() || requestHeaders.get("host") || "localhost:3000";
  const protocol = requestHeaders.get("x-forwarded-proto")?.split(",")[0]?.trim() || (host.includes("localhost") ? "http" : "https");
  return new Request(`${protocol}://${host}/`);
}

export async function publicSiteUrlForCurrentRequest(path = "/") {
  const request = await requestForCurrentHost();
  return new URL(path, `${publicSiteOrigin(request)}/`).toString();
}

export async function currentRequestIsStudio() {
  return isStudioRequest(await requestForCurrentHost());
}

export async function currentRequestIsLocalQa() {
  return isLocalQaRequest(await requestForCurrentHost());
}
