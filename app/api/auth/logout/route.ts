import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { assertSameOrigin, deleteSession, safeReturnTo, SESSION_COOKIE } from "../../../lib/auth";
import { clearSessionCookie, redirectTo } from "../../../lib/auth-http";
import { auth0WebLogoutUrl } from "../../../lib/auth0-web";

export async function POST(request: Request) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const form = await request.formData();
  const returnTo = safeReturnTo(form.get("return_to"), "/");
  const cookieStore = await cookies();
  await deleteSession(cookieStore.get(SESSION_COOKIE)?.value);
  const providerLogoutUrl = await auth0WebLogoutUrl(request, returnTo);
  const response = providerLogoutUrl
    ? NextResponse.redirect(providerLogoutUrl, 303)
    : redirectTo(request, returnTo);
  clearSessionCookie(response);
  response.headers.set("Cache-Control", "private, no-store");
  response.headers.set("Referrer-Policy", "no-referrer");
  return response;
}
