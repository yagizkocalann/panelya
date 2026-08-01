import {
  assertAccountMutationOrigin,
  getAccountActor,
  objectInput,
  readLimitedAccountJson,
  requireAccountActor,
} from "../../lib/account-runtime";
import {
  listProgressItems,
  PROGRESS_JSON_HEADERS,
  progressErrorResponse,
  upsertProgressItem,
} from "../../lib/progress-runtime";

export async function GET(request: Request) {
  try {
    const actor = await requireAccountActor(request, ["write:progress"]);
    return Response.json({
      schemaVersion: "1.0",
      items: await listProgressItems(actor.user.id),
    }, { headers: PROGRESS_JSON_HEADERS });
  } catch (error) {
    return progressErrorResponse(error);
  }
}

export async function POST(request: Request) {
  try {
    const actor = await getAccountActor(request, ["write:progress"]);
    // Anonim web okuyucusu ilerlemeyi cihazında tutar; mevcut sessiz no-op korunur.
    if (!actor) return new Response(null, { status: 204, headers: PROGRESS_JSON_HEADERS });
    assertAccountMutationOrigin(request, actor);
    const input = objectInput(
      await readLimitedAccountJson(request),
      ["seriesSlug", "episodeSlug", "percent"],
    );
    const item = await upsertProgressItem(
      actor.user.id,
      input.seriesSlug,
      input.episodeSlug,
      input.percent,
    );
    return Response.json({ schemaVersion: "1.0", item }, { headers: PROGRESS_JSON_HEADERS });
  } catch (error) {
    return progressErrorResponse(error);
  }
}
