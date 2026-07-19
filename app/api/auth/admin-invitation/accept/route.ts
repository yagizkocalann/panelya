import { NextResponse } from "next/server";
import { acceptAdminInvitation, inspectAdminInvitation } from "../../../../lib/admin-invitations";
import { assertSameOrigin, createSession, validatePassword } from "../../../../lib/auth";
import { setSessionCookie } from "../../../../lib/auth-http";
import { writeAudit } from "../../../../lib/database";
import { consumeRateLimit, requestFingerprint } from "../../../../lib/rate-limit";
import { isStudioRequest } from "../../../../lib/site-origins";

function errorRedirect(request: Request, token: string, message: string) {
  const url = new URL("/accept-admin-invite", request.url);
  url.searchParams.set("token", token);
  url.searchParams.set("error", message);
  return NextResponse.redirect(url, 303);
}

export async function POST(request: Request) {
  if (!isStudioRequest(request)) return new Response("Not found", { status: 404 });
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const form = await request.formData();
  const token = String(form.get("token") ?? "");
  const displayName = String(form.get("display_name") ?? "").trim();
  const password = String(form.get("password") ?? "");
  const confirmation = String(form.get("password_confirmation") ?? "");
  const invitation = await inspectAdminInvitation(token);
  const allowed = await consumeRateLimit("admin-invitation-accept", await requestFingerprint(request, invitation?.email ?? "invalid"), 10, 30 * 60 * 1000);
  if (!allowed) return errorRedirect(request, token, "Çok fazla deneme yapıldı. Biraz sonra yeniden dene.");
  if (!invitation) return errorRedirect(request, token, "Davet bağlantısı geçersiz, kullanılmış veya süresi dolmuş.");
  if (displayName.length < 2 || displayName.length > 40) return errorRedirect(request, token, "Ad 2–40 karakter olmalı.");
  const passwordError = validatePassword(password);
  if (passwordError) return errorRedirect(request, token, passwordError);
  if (password !== confirmation) return errorRedirect(request, token, "Şifreler eşleşmiyor.");
  if (form.get("terms") !== "accepted") return errorRedirect(request, token, "Kullanım koşullarını kabul etmelisin.");
  try {
    const accepted = await acceptAdminInvitation(token, displayName, password);
    if (!accepted) return errorRedirect(request, token, "Davet bağlantısı artık kullanılamıyor.");
    await writeAudit(accepted.user.id, "admin.invitation_accepted", { invitationId: accepted.invitationId, targetUserId: accepted.user.id, role: "admin" });
    const session = await createSession(accepted.user.id, true, request);
    const response = NextResponse.redirect(new URL("/?invite=accepted", request.url), 303);
    setSessionCookie(response, request, session.rawToken, session.expiresAt);
    return response;
  } catch (error) {
    if (String(error).toLowerCase().includes("unique")) return errorRedirect(request, token, "Bu e-posta artık başka bir hesaba bağlı.");
    console.error("admin_invitation_accept_failed", { errorName: error instanceof Error ? error.name : "unknown" });
    return errorRedirect(request, token, "Davet kabul edilemedi. Yeniden dene.");
  }
}
