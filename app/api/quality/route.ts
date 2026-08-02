import { assertSameOrigin } from "../../lib/auth";
import { parseQualityEvent, qualityLogArguments } from "../../lib/quality-observability";
import { qualityTelemetryMode } from "../../lib/runtime-config";

const MAX_BODY_BYTES = 2_048;

function noStore(status = 204) {
  return new Response(null, { status, headers: { "Cache-Control": "no-store" } });
}

export async function POST(request: Request) {
  try {
    assertSameOrigin(request);
  } catch {
    return noStore(403);
  }

  const contentLength = Number(request.headers.get("content-length") ?? 0);
  if (Number.isFinite(contentLength) && contentLength > MAX_BODY_BYTES) return noStore(413);
  if (!request.headers.get("content-type")?.toLowerCase().startsWith("application/json")) return noStore(415);

  const text = await request.text();
  if (new TextEncoder().encode(text).byteLength > MAX_BODY_BYTES) return noStore(413);

  let decoded: unknown;
  try {
    decoded = JSON.parse(text);
  } catch {
    return noStore(400);
  }
  const event = parseQualityEvent(decoded);
  if (!event) return noStore(400);

  const mode = await qualityTelemetryMode();
  if (mode === "disabled") return noStore();
  if (mode !== "cloudflare_logs") return noStore(503);

  // Olay sekli bilincli olarak message, stack, query, referrer, user/session,
  // token ve user-agent tasimaz. Cloudflare log adapter'i yalniz bu allowlist'i
  // alir; ham request veya exception hicbir zaman loglanmaz.
  console.info(...qualityLogArguments(event));
  return noStore();
}
