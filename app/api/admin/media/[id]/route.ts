import { getCurrentUser } from "../../../../lib/auth";
import { getMediaAsset } from "../../../../lib/media/repository";
import { getMediaStorage } from "../../../../lib/media/storage";
import { isStudioRequest } from "../../../../lib/site-origins";

export async function GET(request: Request, { params }: { params: Promise<{ id: string }> }) {
  if (!isStudioRequest(request)) return new Response("Not found", { status: 404 });
  const user = await getCurrentUser();
  if (!user || user.role !== "admin") return new Response("Not found", { status: 404 });
  const { id } = await params;
  const asset = await getMediaAsset(id);
  if (!asset) return new Response("Not found", { status: 404 });
  const object = await (await getMediaStorage()).get(asset.storageKey);
  if (!object?.body) return new Response("Not found", { status: 404 });
  return new Response(object.body, { headers: { "Content-Type": asset.mimeType, "Content-Length": String(asset.byteSize), "Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff", "Content-Disposition": "inline" } });
}
