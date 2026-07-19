import { getMediaVariant } from "../../../lib/media/derivatives";
import { getMediaAsset, isPublicMediaAsset } from "../../../lib/media/repository";
import { getMediaStorage } from "../../../lib/media/storage";

export async function GET(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const asset = await getMediaAsset(id);
  if (!asset || !(await isPublicMediaAsset(asset))) return new Response("Not found", { status: 404 });
  const requestedWidth = Number(new URL(request.url).searchParams.get("width"));
  const variant = Number.isInteger(requestedWidth) ? await getMediaVariant(asset.id, requestedWidth) : null;
  const delivery = variant ?? asset;
  const object = await (await getMediaStorage()).get(delivery.storageKey);
  if (!object?.body) return new Response("Not found", { status: 404 });
  const cacheControl = requestedWidth && !variant ? "public, max-age=60" : "public, max-age=31536000, immutable";
  return new Response(object.body, { headers: { "Content-Type": delivery.mimeType, "Content-Length": String(delivery.byteSize), "Cache-Control": cacheControl, "X-Content-Type-Options": "nosniff", "ETag": object.etag ?? delivery.id } });
}
