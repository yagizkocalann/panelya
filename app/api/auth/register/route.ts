import { assertSameOrigin, createSession, createUser, safeReturnTo, validateRegistration } from "../../../lib/auth";
import { errorRedirect, redirectTo, setSessionCookie } from "../../../lib/auth-http";
import { queueEmailVerification } from "../../../lib/account-flows";
import { consumeRateLimit, requestFingerprint } from "../../../lib/rate-limit";
import { isLocalQaRequest } from "../../../lib/site-origins";

export async function POST(request: Request) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const form = await request.formData();
  const displayName = String(form.get("display_name") ?? "");
  const email = String(form.get("email") ?? "");
  const password = String(form.get("password") ?? "");
  const passwordConfirmation = String(form.get("password_confirmation") ?? "");
  const returnTo = safeReturnTo(form.get("return_to"));
  const allowed = await consumeRateLimit("register", await requestFingerprint(request, email), 5, 15 * 60 * 1000);
  if (!allowed) return errorRedirect(request, "/register", "Çok fazla deneme yapıldı. Biraz sonra yeniden dene.", returnTo);
  const validationError = validateRegistration(displayName, email, password);
  if (validationError) return errorRedirect(request, "/register", validationError, returnTo);
  if (password !== passwordConfirmation) return errorRedirect(request, "/register", "Şifreler eşleşmiyor.", returnTo);
  if (form.get("terms") !== "accepted") return errorRedirect(request, "/register", "Kullanım koşullarını kabul etmelisin.", returnTo);
  try {
    const user = await createUser(displayName, email, password, isLocalQaRequest(request));
    await queueEmailVerification(user.id, user.email, new URL(request.url).origin);
    const session = await createSession(user.id, true, request.headers.get("user-agent"));
    const response = redirectTo(request, returnTo);
    setSessionCookie(response, request, session.rawToken, session.expiresAt);
    return response;
  } catch (error) {
    if (String(error).toLowerCase().includes("unique")) return errorRedirect(request, "/register", "Bu e-posta zaten kayıtlı.", returnTo);
    console.error("register_failed", error);
    return errorRedirect(request, "/register", "Kayıt sırasında bir hata oluştu.", returnTo);
  }
}
