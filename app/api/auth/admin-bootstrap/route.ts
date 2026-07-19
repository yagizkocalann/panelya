import { NextResponse } from "next/server";
import { createBootstrapAdmin, hasAdminAccount } from "../../../lib/admin-invitations";
import { assertSameOrigin, createSession, hashOpaqueToken, validatePassword } from "../../../lib/auth";
import { setSessionCookie } from "../../../lib/auth-http";
import { writeAudit } from "../../../lib/database";
import { consumeRateLimit, requestFingerprint } from "../../../lib/rate-limit";
import { adminBootstrapToken } from "../../../lib/runtime-config";
import { isStudioRequest } from "../../../lib/site-origins";

function errorRedirect(request: Request, message: string) {
  const url = new URL("/bootstrap-admin", request.url);
  url.searchParams.set("error", message);
  return NextResponse.redirect(url, 303);
}

async function secretsMatch(left: string, right: string) {
  const [leftHash, rightHash] = await Promise.all([hashOpaqueToken(left), hashOpaqueToken(right)]);
  let difference = leftHash.length ^ rightHash.length;
  for (let index = 0; index < Math.max(leftHash.length, rightHash.length); index += 1) {
    difference |= (leftHash.charCodeAt(index) || 0) ^ (rightHash.charCodeAt(index) || 0);
  }
  return difference === 0;
}

export async function POST(request: Request) {
  if (!isStudioRequest(request)) return new Response("Not found", { status: 404 });
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const expectedToken = await adminBootstrapToken();
  if (expectedToken.length < 32 || await hasAdminAccount()) return new Response("Not found", { status: 404 });
  const allowed = await consumeRateLimit("admin-bootstrap", await requestFingerprint(request, "bootstrap"), 5, 30 * 60 * 1000);
  if (!allowed) return errorRedirect(request, "Çok fazla deneme yapıldı. Biraz sonra yeniden dene.");
  const form = await request.formData();
  const displayName = String(form.get("display_name") ?? "").trim();
  const email = String(form.get("email") ?? "");
  const password = String(form.get("password") ?? "");
  const confirmation = String(form.get("password_confirmation") ?? "");
  const submittedToken = String(form.get("bootstrap_token") ?? "");
  if (!(await secretsMatch(submittedToken, expectedToken))) return errorRedirect(request, "Kurulum bilgileri doğrulanamadı.");
  if (displayName.length < 2 || displayName.length > 40) return errorRedirect(request, "Ad 2–40 karakter olmalı.");
  const passwordError = validatePassword(password);
  if (passwordError) return errorRedirect(request, passwordError);
  if (password !== confirmation) return errorRedirect(request, "Şifreler eşleşmiyor.");
  if (form.get("terms") !== "accepted") return errorRedirect(request, "Kullanım koşullarını kabul etmelisin.");
  try {
    const user = await createBootstrapAdmin(displayName, email, password);
    if (!user) return new Response("Not found", { status: 404 });
    await writeAudit(user.id, "admin.bootstrap_completed", { targetUserId: user.id, role: "admin" });
    const session = await createSession(user.id, true, request);
    const response = NextResponse.redirect(new URL("/?bootstrap=completed", request.url), 303);
    setSessionCookie(response, request, session.rawToken, session.expiresAt);
    return response;
  } catch (error) {
    if (String(error).toLowerCase().includes("unique")) return errorRedirect(request, "Bu e-posta zaten başka bir hesaba bağlı.");
    console.error("admin_bootstrap_failed", { errorName: error instanceof Error ? error.name : "unknown" });
    return errorRedirect(request, "Yönetici oluşturulamadı. Yeniden dene.");
  }
}
