import { NextResponse } from "next/server";
import { Auth0RuntimeError } from "../../../../lib/auth0-runtime";
import { clearAuth0WebState, completeAuth0WebLogin } from "../../../../lib/auth0-web";

export async function GET(request: Request) {
  try {
    return await completeAuth0WebLogin(request);
  } catch (error) {
    const runtimeError = error instanceof Auth0RuntimeError
      ? error
      : new Auth0RuntimeError("service_unavailable", "Web giriş işlemi tamamlanamadı.", 503, false, 60);
    const url = new URL("/login", request.url);
    url.searchParams.set("error", runtimeError.message.slice(0, 180));
    const response = NextResponse.redirect(url, 303);
    clearAuth0WebState(response);
    response.headers.set("Cache-Control", "private, no-store");
    response.headers.set("Referrer-Policy", "no-referrer");
    return response;
  }
}
