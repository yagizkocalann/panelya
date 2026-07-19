const DEFAULT_PUBLIC_ORIGIN = "http://localhost:3000";
const DEFAULT_STUDIO_ORIGIN = "http://studio.localhost:3000";

function configuredOrigin(value: string | undefined, fallback: string) {
  try {
    return new URL(value || fallback).origin;
  } catch {
    return fallback;
  }
}

function derivedLocalOrigin(request: Request, hostname: string) {
  const url = new URL(request.url);
  url.hostname = hostname;
  url.pathname = "/";
  url.search = "";
  url.hash = "";
  return url.origin;
}

export function publicSiteOrigin(request?: Request) {
  if (process.env.PUBLIC_SITE_ORIGIN) return configuredOrigin(process.env.PUBLIC_SITE_ORIGIN, DEFAULT_PUBLIC_ORIGIN);
  return request ? derivedLocalOrigin(request, "localhost") : DEFAULT_PUBLIC_ORIGIN;
}

export function studioSiteOrigin(request?: Request) {
  if (process.env.STUDIO_SITE_ORIGIN) return configuredOrigin(process.env.STUDIO_SITE_ORIGIN, DEFAULT_STUDIO_ORIGIN);
  return request ? derivedLocalOrigin(request, "studio.localhost") : DEFAULT_STUDIO_ORIGIN;
}

export function publicSiteUrl(path = "/") {
  return new URL(path, `${publicSiteOrigin()}/`).toString();
}

export function studioSiteUrl(path = "/") {
  return new URL(path, `${studioSiteOrigin()}/`).toString();
}

export function requestHostname(request: Request) {
  const forwardedHost = request.headers.get("x-forwarded-host")?.split(",")[0]?.trim();
  const host = forwardedHost || request.headers.get("host") || new URL(request.url).host;
  try {
    return new URL(`http://${host}`).hostname.toLowerCase();
  } catch {
    return "";
  }
}

export function isStudioRequest(request: Request) {
  return requestHostname(request) === new URL(studioSiteOrigin(request)).hostname.toLowerCase();
}

export function isLocalQaRequest(request: Request) {
  const hostname = requestHostname(request);
  return hostname === "localhost" || hostname.endsWith(".localhost") || hostname === "127.0.0.1" || hostname === "::1";
}

export function isAllowedAccountActionOrigin(origin: string, request?: Request) {
  return origin === publicSiteOrigin(request) || origin === studioSiteOrigin(request);
}
