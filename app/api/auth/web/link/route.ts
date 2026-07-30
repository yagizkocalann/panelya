import { assertSameOrigin, getCurrentUser, hasRecentAuthentication } from "../../../../lib/auth";
import { Auth0RuntimeError } from "../../../../lib/auth0-runtime";
import { startAuth0WebLogin } from "../../../../lib/auth0-web";
import { consumeRateLimit, requestFingerprint } from "../../../../lib/rate-limit";

export async function POST(request: Request) {
  try {
    assertSameOrigin(request);
  } catch {
    return new Response("Geçersiz istek.", { status: 403 });
  }
  const user = await getCurrentUser();
  if (!user) {
    return new Response("Hesap bağlantısı için giriş yapmalısın.", {
      status: 401,
      headers: { "Cache-Control": "private, no-store", "Referrer-Policy": "no-referrer" },
    });
  }
  if (!(await hasRecentAuthentication())) {
    return new Response("Hesap bağlantısı için oturumunu yeniden doğrulamalısın.", {
      status: 401,
      headers: { "Cache-Control": "private, no-store", "Referrer-Policy": "no-referrer" },
    });
  }
  const allowed = await consumeRateLimit(
    "auth0-web-link",
    await requestFingerprint(request, user.id),
    5,
    60 * 60 * 1000,
  );
  if (!allowed) {
    return new Response("Çok fazla hesap bağlantısı isteği yapıldı.", {
      status: 429,
      headers: {
        "Cache-Control": "private, no-store",
        "Referrer-Policy": "no-referrer",
        "Retry-After": "300",
      },
    });
  }
  try {
    return await startAuth0WebLogin(request, {
      purpose: "link",
      linkUserId: user.id,
      returnTo: "/account?notice=Auth0%20hesabı%20bağlandı.",
      remember: true,
    });
  } catch (error) {
    const runtimeError = error instanceof Auth0RuntimeError
      ? error
      : new Auth0RuntimeError("service_unavailable", "Hesap bağlantısı başlatılamadı.", 503, false, 60);
    return new Response(runtimeError.message, {
      status: runtimeError.status,
      headers: {
        "Cache-Control": "private, no-store",
        "Referrer-Policy": "no-referrer",
        ...(runtimeError.retryAfterSeconds ? { "Retry-After": String(runtimeError.retryAfterSeconds) } : {}),
      },
    });
  }
}
