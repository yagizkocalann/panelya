import { requireAccountActor } from "../../lib/account-runtime";
import {
  LIBRARY_JSON_HEADERS,
  libraryErrorResponse,
  listLibraryItems,
} from "../../lib/library-runtime";

export async function GET(request: Request) {
  try {
    const actor = await requireAccountActor(request, ["read:library"]);
    return Response.json({
      schemaVersion: "1.0",
      items: await listLibraryItems(actor.user.id),
    }, { headers: LIBRARY_JSON_HEADERS });
  } catch (error) {
    return libraryErrorResponse(error);
  }
}
