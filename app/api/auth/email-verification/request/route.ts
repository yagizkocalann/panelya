import { queueEmailVerification } from "../../../../lib/account-flows";
import { assertSameOrigin, getCurrentUser } from "../../../../lib/auth";
import { redirectTo } from "../../../../lib/auth-http";
import { consumeRateLimit, requestFingerprint } from "../../../../lib/rate-limit";

export async function POST(request: Request) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, "/login?return_to=/account");
  if (user.emailVerifiedAt) return redirectTo(request, "/account?notice=E-posta%20adresin%20zaten%20doğrulanmış.");
  const allowed = await consumeRateLimit("email-verification", await requestFingerprint(request, user.id), 4, 30 * 60 * 1000);
  if (!allowed) return redirectTo(request, "/account?error=Çok%20fazla%20doğrulama%20isteği.%20Biraz%20sonra%20yeniden%20dene.");
  await queueEmailVerification(user.id, user.email, new URL(request.url).origin);
  return redirectTo(request, "/account?notice=Yeni%20doğrulama%20bağlantısı%20yerel%20kutuna%20eklendi.");
}
