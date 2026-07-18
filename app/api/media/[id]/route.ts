import { getMediaAsset, isPublicMediaAsset } from "../../../lib/media/repository";
import { getMediaStorage } from "../../../lib/media/storage";

export async function GET(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const asset = await getMediaAsset(id);
  if (!asset || !(await isPublicMediaAsset(asset))) return new Response("Not found", { status: 404 });
  const object = await (await getMediaStorage()).get(asset.storageKey);
  if (!object?.body) return new Response("Not found", { status: 404 });
  return new Response(object.body, { headers: { "Content-Type": asset.mimeType, "Content-Length": String(asset.byteSize), "Cache-Control": "public, max-age=31536000, immutable", "X-Content-Type-Options": "nosniff", "ETag": object.etag ?? asset.id } });
}
