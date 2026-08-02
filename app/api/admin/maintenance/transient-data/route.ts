import { NextResponse } from "next/server";
import { assertSameOrigin, getCurrentUser, hasRecentAuthentication } from "../../../../lib/auth";
import { reauthenticationRedirect, redirectTo } from "../../../../lib/auth-http";
import { writeAudit } from "../../../../lib/database";
import { consumeRateLimit, requestFingerprint } from "../../../../lib/rate-limit";
import { isStudioRequest } from "../../../../lib/site-origins";
import { purgeExpiredTransientData } from "../../../../lib/transient-data-maintenance";

function redirectWith(request: Request, key: "error" | "maintenance", value: string, count?: number) {
  const url = new URL("/qa", request.url);
  url.searchParams.set(key, value);
  if (typeof count === "number") url.searchParams.set("count", String(count));
  return NextResponse.redirect(url, 303);
}

export async function POST(request: Request) {
  if (!isStudioRequest(request)) return new Response("Not found", { status: 404 });
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const actor = await getCurrentUser();
  if (!actor) return redirectTo(request, "/login?return_to=/qa");
  if (actor.role !== "admin") return new Response("Yetkisiz.", { status: 403 });
  if (!(await hasRecentAuthentication())) return reauthenticationRedirect(request, "/qa");
  const allowed = await consumeRateLimit("admin-transient-maintenance", await requestFingerprint(request, actor.id), 4, 60 * 60 * 1000);
  if (!allowed) return redirectWith(request, "error", "Çok fazla bakım işlemi yapıldı. Biraz sonra yeniden dene.");
  const form = await request.formData();
  if (form.get("action") !== "purge_expired") return redirectWith(request, "error", "Bakım işlemi tanınmıyor.");

  try {
    const result = await purgeExpiredTransientData();
    await writeAudit(actor.id, "admin.transient_data_purged", {
      deletedCount: result.total,
      policyVersion: result.policyVersion,
    });
    return redirectWith(request, "maintenance", "purged", result.total);
  } catch (error) {
    console.error("transient_data_purge_failed", { errorType: error instanceof Error ? "exception" : "unknown" });
    return redirectWith(request, "error", "Geçici veri bakımı tamamlanamadı. Yeniden dene.");
  }
}
