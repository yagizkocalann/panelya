import { findUserByEmail, normalizeEmail, assertSameOrigin } from "../../../../lib/auth";
import { queuePasswordReset } from "../../../../lib/account-flows";
import { redirectTo } from "../../../../lib/auth-http";
import { consumeRateLimit, requestFingerprint } from "../../../../lib/rate-limit";

export async function POST(request: Request) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const form = await request.formData();
  const email = normalizeEmail(String(form.get("email") ?? ""));
  const fingerprint = await requestFingerprint(request, email || "empty");
  const allowed = await consumeRateLimit("password-reset", fingerprint, 4, 30 * 60 * 1000);
  if (allowed) {
    const user = await findUserByEmail(email);
    if (user) await queuePasswordReset(user.id, user.email, new URL(request.url).origin);
  }
  return redirectTo(request, "/forgot-password?sent=1");
}
