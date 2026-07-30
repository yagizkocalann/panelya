import { assertSameOrigin, safeReturnTo } from "../../../../lib/auth";
import { errorRedirect } from "../../../../lib/auth-http";
import { Auth0RuntimeError } from "../../../../lib/auth0-runtime";
import { startAuth0WebLogin } from "../../../../lib/auth0-web";
import { consumeRateLimit, requestFingerprint } from "../../../../lib/rate-limit";

export async function POST(request: Request) {
  let returnTo = "/account";
  try {
    assertSameOrigin(request);
    const form = await request.formData();
    returnTo = safeReturnTo(form.get("return_to"), "/account");
    const allowed = await consumeRateLimit(
      "auth0-web-login",
      await requestFingerprint(request, returnTo),
      12,
      15 * 60 * 1000,
    );
    if (!allowed) {
      throw new Auth0RuntimeError("rate_limited", "Çok fazla giriş isteği yapıldı.", 429, false, 60);
    }
    return startAuth0WebLogin(request, {
      returnTo,
      remember: form.get("remember") === "yes",
      ...(form.get("screen_hint") === "signup" ? { screenHint: "signup" as const } : {}),
    });
  } catch (error) {
    const runtimeError = error instanceof Auth0RuntimeError
      ? error
      : new Auth0RuntimeError("invalid_grant", "Web giriş isteği başlatılamadı.", 400, true);
    const response = errorRedirect(request, "/login", runtimeError.message, returnTo);
    response.headers.set("Cache-Control", "private, no-store");
    response.headers.set("Referrer-Policy", "no-referrer");
    if (runtimeError.retryAfterSeconds) {
      response.headers.set("Retry-After", String(runtimeError.retryAfterSeconds));
    }
    return response;
  }
}
