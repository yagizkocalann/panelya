import { assertSameOrigin, getCurrentUser } from "../../../../../lib/auth";
import { redirectTo } from "../../../../../lib/auth-http";
import { writeAudit } from "../../../../../lib/database";
import { redispatchDerivativeJobs } from "../../../../../lib/media/derivatives";
import { isStudioRequest } from "../../../../../lib/site-origins";

export async function POST(request: Request) {
  if (!isStudioRequest(request)) return new Response("Not found", { status: 404 });
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, "/login?return_to=/media");
  if (user.role !== "admin") return new Response("Yetkisiz.", { status: 403 });

  try {
    const result = await redispatchDerivativeJobs();
    await writeAudit(user.id, "media.derivatives_redispatched", { sent: result.sent, failed: result.failed });
    return redirectTo(request, `/media?dispatch_sent=${result.sent}&dispatch_failed=${result.failed}`);
  } catch {
    await writeAudit(user.id, "media.derivatives_redispatch_failed").catch(() => undefined);
    return redirectTo(request, "/media?error=Üretim%20kuyruğu%20şu%20anda%20kullanılamıyor.");
  }
}
