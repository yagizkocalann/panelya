import {
  assertAccountMutationOrigin,
  objectInput,
  readLimitedAccountJson,
  requireAccountActor,
} from "../../../lib/account-runtime";
import { getPublishedSeries } from "../../../lib/content-repository";
import { assertSameOrigin, getCurrentUser, safeReturnTo } from "../../../lib/auth";
import { redirectTo } from "../../../lib/auth-http";
import { writeAudit } from "../../../lib/database";
import {
  getLibraryItem,
  LIBRARY_JSON_HEADERS,
  libraryErrorResponse,
  parseLibraryFavorite,
  parseLibrarySlug,
  parseLibraryStatus,
  removeLibraryItem,
  upsertLibraryItem,
} from "../../../lib/library-runtime";

type RouteContext = { params: Promise<{ slug: string }> };

function isJsonRequest(request: Request) {
  return (request.headers.get("content-type") ?? "").toLowerCase().startsWith("application/json");
}

async function postJson(request: Request, slugValue: string) {
  try {
    const actor = await requireAccountActor(request, ["write:library"]);
    assertAccountMutationOrigin(request, actor);
    const slug = parseLibrarySlug(slugValue);
    const input = objectInput(await readLimitedAccountJson(request), ["status", "favorite"]);
    const item = await upsertLibraryItem(
      actor.user.id,
      slug,
      parseLibraryStatus(input.status),
      parseLibraryFavorite(input.favorite),
    );
    await writeAudit(actor.user.id, "library.set", {
      seriesSlug: slug,
      status: item.status,
      favorite: item.favorite,
      transport: actor.transport,
    });
    return Response.json({ schemaVersion: "1.0", item }, { headers: LIBRARY_JSON_HEADERS });
  } catch (error) {
    return libraryErrorResponse(error);
  }
}

async function postWebForm(request: Request, slugValue: string) {
  try {
    assertSameOrigin(request);
  } catch {
    return new Response("Geçersiz istek.", { status: 403 });
  }
  const slug = parseLibrarySlug(slugValue);
  if (!(await getPublishedSeries(slug))) return new Response("Seri bulunamadı.", { status: 404 });
  const form = await request.formData();
  const returnTo = safeReturnTo(form.get("return_to"), `/${slug}`);
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, `/login?return_to=${encodeURIComponent(returnTo)}`);
  const action = String(form.get("action") ?? "add");

  if (action === "remove") {
    await removeLibraryItem(user.id, slug);
  } else if (action === "favorite") {
    const current = await getLibraryItem(user.id, slug);
    await upsertLibraryItem(user.id, slug, current?.status ?? "plan", !current?.favorite);
  } else if (action === "status") {
    const current = await getLibraryItem(user.id, slug);
    await upsertLibraryItem(
      user.id,
      slug,
      parseLibraryStatus(form.get("status") ?? "plan"),
      current?.favorite ?? false,
    );
  } else {
    const current = await getLibraryItem(user.id, slug);
    await upsertLibraryItem(user.id, slug, current?.status ?? "plan", current?.favorite ?? false);
  }
  await writeAudit(user.id, `library.${action}`, { seriesSlug: slug, transport: "web" });
  return redirectTo(request, returnTo);
}

export async function POST(request: Request, { params }: RouteContext) {
  const { slug } = await params;
  if (isJsonRequest(request)) return postJson(request, slug);
  try {
    return await postWebForm(request, slug);
  } catch (error) {
    return libraryErrorResponse(error);
  }
}

export async function DELETE(request: Request, { params }: RouteContext) {
  try {
    const actor = await requireAccountActor(request, ["write:library"]);
    assertAccountMutationOrigin(request, actor);
    const slug = parseLibrarySlug((await params).slug);
    const removed = await removeLibraryItem(actor.user.id, slug);
    await writeAudit(actor.user.id, "library.remove", {
      seriesSlug: slug,
      removed,
      transport: actor.transport,
    });
    return Response.json({ schemaVersion: "1.0", removed }, { headers: LIBRARY_JSON_HEADERS });
  } catch (error) {
    return libraryErrorResponse(error);
  }
}
