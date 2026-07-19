import { NextResponse } from "next/server";
import { AdminInvitationError, createAdminInvitation } from "../../../lib/admin-invitations";
import { assertSameOrigin, getCurrentUser } from "../../../lib/auth";
import { redirectTo } from "../../../lib/auth-http";
import { writeAudit } from "../../../lib/database";
import { consumeRateLimit, requestFingerprint } from "../../../lib/rate-limit";
import { isStudioRequest, studioSiteOrigin } from "../../../lib/site-origins";

function redirectWith(request: Request, key: "error" | "invite", value: string) {
  const url = new URL("/users", request.url);
  url.searchParams.set(key, value);
  return NextResponse.redirect(url, 303);
}

function invitationError(request: Request, error: AdminInvitationError) {
  const messages = {
    invalid_email: "Geçerli bir e-posta adresi gir.",
    account_exists: "Bu e-posta zaten bir Panelya hesabına bağlı; rol yönetimini kullan.",
    pending_exists: "Bu e-posta için zaten bekleyen bir yönetici daveti var.",
    not_pending: "Davet artık beklemede değil.",
  };
  return redirectWith(request, "error", messages[error.code]);
}

export async function POST(request: Request) {
  if (!isStudioRequest(request)) return new Response("Not found", { status: 404 });
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const actor = await getCurrentUser();
  if (!actor) return redirectTo(request, "/login?return_to=/users");
  if (actor.role !== "admin") return new Response("Yetkisiz.", { status: 403 });
  const allowed = await consumeRateLimit("admin-invitation", await requestFingerprint(request, actor.id), 20, 60 * 60 * 1000);
  if (!allowed) return redirectWith(request, "error", "Çok fazla davet işlemi yapıldı. Biraz sonra yeniden dene.");
  const form = await request.formData();
  try {
    const invitation = await createAdminInvitation(actor.id, String(form.get("email") ?? ""), studioSiteOrigin(request));
    await writeAudit(actor.id, "admin.invitation_created", { invitationId: invitation.id, role: "admin", expiresAt: invitation.expiresAt });
    return redirectWith(request, "invite", "created");
  } catch (error) {
    if (error instanceof AdminInvitationError) return invitationError(request, error);
    console.error("admin_invitation_create_failed", { errorName: error instanceof Error ? error.name : "unknown" });
    return redirectWith(request, "error", "Davet oluşturulamadı. Yeniden dene.");
  }
}
