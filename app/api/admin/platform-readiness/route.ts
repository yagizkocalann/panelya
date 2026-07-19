import { getCurrentUser } from "../../../lib/auth";
import { getPlatformReadiness } from "../../../lib/platform-readiness";
import { isStudioRequest } from "../../../lib/site-origins";

const RESPONSE_HEADERS = { "Cache-Control": "private, no-store" } as const;

export async function GET(request: Request) {
  if (!isStudioRequest(request)) return new Response("Not found", { status: 404 });
  const user = await getCurrentUser();
  if (!user) return Response.json({ error: "unauthenticated" }, { status: 401, headers: RESPONSE_HEADERS });
  if (user.role !== "admin") return Response.json({ error: "forbidden" }, { status: 403, headers: RESPONSE_HEADERS });

  const readiness = await getPlatformReadiness();
  return Response.json(readiness, { status: readiness.automatedReady ? 200 : 503, headers: RESPONSE_HEADERS });
}
