import { assertSameOrigin, getCurrentUser, getPasswordHash, rotateCurrentSessionAfterReauthentication, safeReturnTo, verifyPassword } from "../../../lib/auth";
import { errorRedirect, redirectTo, setSessionCookie } from "../../../lib/auth-http";
import { writeAudit } from "../../../lib/database";
import { consumeRateLimit, requestFingerprint } from "../../../lib/rate-limit";

export async function POST(request: Request) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const form = await request.formData();
  const returnTo = safeReturnTo(form.get("return_to"), "/account");
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, `/login?return_to=${encodeURIComponent(returnTo)}`);
  const allowed = await consumeRateLimit("reauthenticate", await requestFingerprint(request, user.id), 5, 15 * 60 * 1000);
  if (!allowed) return errorRedirect(request, "/reauthenticate", "Çok fazla doğrulama denemesi yapıldı. Biraz sonra yeniden dene.", returnTo);
  const stored = await getPasswordHash(user.id);
  const password = String(form.get("password") ?? "");
  if (!stored || !(await verifyPassword(password, stored.password_hash))) {
    return errorRedirect(request, "/reauthenticate", "Şifre doğrulanamadı.", returnTo);
  }
  const session = await rotateCurrentSessionAfterReauthentication();
  if (!session) return redirectTo(request, `/login?return_to=${encodeURIComponent(returnTo)}`);
  await writeAudit(user.id, "account.reauthenticated");
  const response = redirectTo(request, returnTo);
  setSessionCookie(response, request, session.rawToken, session.expiresAt);
  return response;
}
