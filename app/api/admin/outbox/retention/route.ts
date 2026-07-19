import { NextResponse } from "next/server";
import { assertSameOrigin, getCurrentUser, hasRecentAuthentication } from "../../../../lib/auth";
import { reauthenticationRedirect, redirectTo } from "../../../../lib/auth-http";
import { writeAudit } from "../../../../lib/database";
import { OUTBOX_RETENTION_POLICY_VERSION, purgeExpiredOutbox } from "../../../../lib/notification-outbox";
import { consumeRateLimit, requestFingerprint } from "../../../../lib/rate-limit";
import { isStudioRequest } from "../../../../lib/site-origins";

function redirectWith(request: Request, key: "error" | "retention", value: string, count?: number) {
  const url = new URL("/outbox", request.url);
  url.searchParams.set(key, value);
  if (typeof count === "number") url.searchParams.set("count", String(count));
  return NextResponse.redirect(url, 303);
}

export async function POST(request: Request) {
  if (!isStudioRequest(request)) return new Response("Not found", { status: 404 });
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const actor = await getCurrentUser();
  if (!actor) return redirectTo(request, "/login?return_to=/outbox");
  if (actor.role !== "admin") return new Response("Yetkisiz.", { status: 403 });
  if (!(await hasRecentAuthentication())) return reauthenticationRedirect(request, "/outbox");
  const allowed = await consumeRateLimit("admin-outbox-retention", await requestFingerprint(request, actor.id), 10, 60 * 60 * 1000);
  if (!allowed) return redirectWith(request, "error", "Çok fazla bakım işlemi yapıldı. Biraz sonra yeniden dene.");
  const form = await request.formData();
  if (form.get("action") !== "purge_expired") return redirectWith(request, "error", "Bakım işlemi tanınmıyor.");
  try {
    const deletedCount = await purgeExpiredOutbox();
    await writeAudit(actor.id, "admin.notification_outbox_purged", { deletedCount, policyVersion: OUTBOX_RETENTION_POLICY_VERSION });
    return redirectWith(request, "retention", "purged", deletedCount);
  } catch (error) {
    console.error("notification_outbox_purge_failed", { errorName: error instanceof Error ? error.name : "unknown" });
    return redirectWith(request, "error", "Outbox bakımı tamamlanamadı. Yeniden dene.");
  }
}
