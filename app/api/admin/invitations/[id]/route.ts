import { NextResponse } from "next/server";
import { AdminInvitationError, resendAdminInvitation, revokeAdminInvitation } from "../../../../lib/admin-invitations";
import { assertSameOrigin, getCurrentUser, hasRecentAuthentication } from "../../../../lib/auth";
import { reauthenticationRedirect, redirectTo } from "../../../../lib/auth-http";
import { writeAudit } from "../../../../lib/database";
import { consumeRateLimit, requestFingerprint } from "../../../../lib/rate-limit";
import { isStudioRequest, studioSiteOrigin } from "../../../../lib/site-origins";

function redirectWith(request: Request, key: "error" | "invite", value: string) {
  const url = new URL("/users", request.url);
  url.searchParams.set(key, value);
  return NextResponse.redirect(url, 303);
}

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  if (!isStudioRequest(request)) return new Response("Not found", { status: 404 });
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const actor = await getCurrentUser();
  if (!actor) return redirectTo(request, "/login?return_to=/users");
  if (actor.role !== "admin") return new Response("Yetkisiz.", { status: 403 });
  if (!(await hasRecentAuthentication())) return reauthenticationRedirect(request, "/users");
  const { id } = await params;
  const allowed = await consumeRateLimit("admin-invitation-update", await requestFingerprint(request, actor.id), 30, 60 * 60 * 1000);
  if (!allowed) return redirectWith(request, "error", "Çok fazla davet işlemi yapıldı. Biraz sonra yeniden dene.");
  const form = await request.formData();
  const action = String(form.get("action") ?? "");
  try {
    if (action === "revoke") {
      if (!(await revokeAdminInvitation(id))) return redirectWith(request, "error", "Davet zaten kapalı veya bulunamadı.");
      await writeAudit(actor.id, "admin.invitation_revoked", { invitationId: id, role: "admin" });
      return redirectWith(request, "invite", "revoked");
    }
    if (action === "resend") {
      const invitation = await resendAdminInvitation(id, studioSiteOrigin(request));
      await writeAudit(actor.id, "admin.invitation_resent", { invitationId: id, role: "admin", expiresAt: invitation.expiresAt });
      return redirectWith(request, "invite", "resent");
    }
    return redirectWith(request, "error", "Davet işlemi tanınmıyor.");
  } catch (error) {
    if (error instanceof AdminInvitationError) {
      const message = error.code === "account_exists" ? "E-posta artık bir hesaba bağlı; davet kullanılamaz." : "Davet artık beklemede değil.";
      return redirectWith(request, "error", message);
    }
    console.error("admin_invitation_update_failed", { errorName: error instanceof Error ? error.name : "unknown" });
    return redirectWith(request, "error", "Davet güncellenemedi. Yeniden dene.");
  }
}
