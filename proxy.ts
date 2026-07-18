import { NextRequest, NextResponse } from "next/server";
import { isStudioRequest, publicSiteOrigin, studioSiteOrigin } from "./app/lib/site-origins";

const STUDIO_SECTIONS = new Set(["content", "media", "messages", "ads", "outbox", "moderation"]);

function copySearch(from: URL, to: URL) {
  to.search = from.search;
  return to;
}

function cleanStudioPath(pathname: string) {
  if (pathname === "/studio") return "/";
  return pathname.startsWith("/studio/") ? pathname.slice("/studio".length) : pathname;
}

function internalStudioPath(pathname: string) {
  if (pathname === "/") return "/studio";
  const section = pathname.split("/").filter(Boolean)[0];
  return section && STUDIO_SECTIONS.has(section) ? `/studio${pathname}` : null;
}

function isStudioSupportPath(pathname: string) {
  return ["/login", "/register", "/forgot-password", "/reset-password", "/verify-email", "/account"].some(
    (path) => pathname === path || pathname.startsWith(`${path}/`),
  ) || pathname.startsWith("/api/auth/") || pathname.startsWith("/api/account/") || pathname.startsWith("/api/admin/");
}

export function proxy(request: NextRequest) {
  const url = request.nextUrl;

  if (isStudioRequest(request)) {
    if (url.pathname === "/studio" || url.pathname.startsWith("/studio/")) {
      return NextResponse.redirect(copySearch(url, new URL(cleanStudioPath(url.pathname), studioSiteOrigin(request))));
    }

    const internalPath = internalStudioPath(url.pathname);
    if (internalPath) {
      const destination = url.clone();
      destination.pathname = internalPath;
      return NextResponse.rewrite(destination);
    }

    if (isStudioSupportPath(url.pathname)) return NextResponse.next();

    return NextResponse.redirect(copySearch(url, new URL(url.pathname, publicSiteOrigin(request))));
  }

  if (url.pathname === "/studio" || url.pathname.startsWith("/studio/")) {
    return NextResponse.redirect(copySearch(url, new URL(cleanStudioPath(url.pathname), studioSiteOrigin(request))));
  }

  if (url.pathname.startsWith("/api/admin/")) return new NextResponse("Not found", { status: 404 });

  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|images/).*)"],
};
