import { assertSameOrigin, authenticate, createSession, safeReturnTo } from "../../../lib/auth";
import { errorRedirect, redirectTo, setSessionCookie } from "../../../lib/auth-http";
import { writeAudit } from "../../../lib/database";
import { consumeRateLimit, requestFingerprint } from "../../../lib/rate-limit";

export async function POST(request: Request) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const form = await request.formData();
  const email = String(form.get("email") ?? "");
  const password = String(form.get("password") ?? "");
  const returnTo = safeReturnTo(form.get("return_to"));
  const allowed = await consumeRateLimit("login", await requestFingerprint(request, email), 8, 15 * 60 * 1000);
  if (!allowed) return errorRedirect(request, "/login", "Çok fazla giriş denemesi yapıldı. Biraz sonra yeniden dene.", returnTo);
  const user = await authenticate(email, password);
  if (!user) return errorRedirect(request, "/login", "E-posta veya şifre hatalı.", returnTo);
  const session = await createSession(user.id, form.get("remember") === "yes", request);
  await writeAudit(user.id, "account.logged_in");
  const response = redirectTo(request, returnTo);
  setSessionCookie(response, request, session.rawToken, session.expiresAt);
  return response;
}
