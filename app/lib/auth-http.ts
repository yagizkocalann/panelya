import { NextResponse } from "next/server";
import { safeReturnTo, SESSION_COOKIE } from "./auth";

export function redirectTo(request: Request, path: string) {
  return NextResponse.redirect(new URL(path, request.url), 303);
}

export function setSessionCookie(response: NextResponse, request: Request, rawToken: string, expiresAt: number) {
  response.cookies.set(SESSION_COOKIE, rawToken, {
    httpOnly: true,
    sameSite: "lax",
    secure: new URL(request.url).protocol === "https:",
    path: "/",
    expires: new Date(expiresAt),
  });
}

export function clearSessionCookie(response: NextResponse) {
  response.cookies.set(SESSION_COOKIE, "", { httpOnly: true, sameSite: "lax", path: "/", expires: new Date(0) });
}

export function errorRedirect(request: Request, basePath: string, message: string, returnTo?: string) {
  const url = new URL(basePath, request.url);
  url.searchParams.set("error", message);
  if (returnTo) url.searchParams.set("return_to", returnTo);
  return NextResponse.redirect(url, 303);
}

export function reauthenticationRedirect(request: Request, returnTo: string) {
  const url = new URL("/reauthenticate", request.url);
  url.searchParams.set("return_to", safeReturnTo(returnTo, "/"));
  return NextResponse.redirect(url, 303);
}
