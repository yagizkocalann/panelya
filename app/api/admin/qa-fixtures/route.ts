import { NextResponse } from "next/server";
import { assertSameOrigin, getCurrentUser, hasRecentAuthentication, validatePassword } from "../../../lib/auth";
import { reauthenticationRedirect, redirectTo } from "../../../lib/auth-http";
import { writeAudit } from "../../../lib/database";
import { LOCAL_QA_FIXTURE_VERSION, resetLocalQaFixtures, seedLocalQaFixtures } from "../../../lib/local-qa-fixtures";
import { consumeRateLimit, requestFingerprint } from "../../../lib/rate-limit";
import { isLocalQaRequest, isStudioRequest } from "../../../lib/site-origins";

function redirectWith(request: Request, key: "error" | "fixtures", value: string) {
  const url = new URL("/qa", request.url);
  url.searchParams.set(key, value);
  return NextResponse.redirect(url, 303);
}

export async function POST(request: Request) {
  if (!isStudioRequest(request) || !isLocalQaRequest(request)) return new Response("Not found", { status: 404 });
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const actor = await getCurrentUser();
  if (!actor) return redirectTo(request, "/login?return_to=/qa");
  if (actor.role !== "admin") return new Response("Yetkisiz.", { status: 403 });
  if (!(await hasRecentAuthentication())) return reauthenticationRedirect(request, "/qa");
  const allowed = await consumeRateLimit("admin-qa-fixtures", await requestFingerprint(request, actor.id), 20, 60 * 60 * 1000);
  if (!allowed) return redirectWith(request, "error", "Çok fazla QA veri işlemi yapıldı. Biraz sonra yeniden dene.");

  const form = await request.formData();
  const action = String(form.get("action") ?? "");
  try {
    if (action === "seed") {
      const password = String(form.get("fixture_password") ?? "");
      const passwordError = validatePassword(password);
      if (passwordError) return redirectWith(request, "error", passwordError);
      const status = await seedLocalQaFixtures(password);
      await writeAudit(actor.id, "admin.qa_fixtures_seeded", {
        fixtureVersion: LOCAL_QA_FIXTURE_VERSION,
        users: status.users,
        series: status.series,
      });
      return redirectWith(request, "fixtures", "seeded");
    }
    if (action === "reset") {
      await resetLocalQaFixtures();
      await writeAudit(actor.id, "admin.qa_fixtures_reset", { fixtureVersion: LOCAL_QA_FIXTURE_VERSION });
      return redirectWith(request, "fixtures", "reset");
    }
    return redirectWith(request, "error", "QA veri işlemi tanınmıyor.");
  } catch (error) {
    console.error("local_qa_fixtures_failed", { errorName: error instanceof Error ? error.name : "unknown", action });
    return redirectWith(request, "error", "QA veri paketi güncellenemedi. Yeniden dene.");
  }
}
