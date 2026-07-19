import { getStudioSeries } from "../../../../lib/content-repository";
import { getMediaAsset } from "../../../../lib/media/repository";
import { getMediaStorage } from "../../../../lib/media/storage";
import { resolvePreviewGrant } from "../../../../lib/preview-tokens";

export async function GET(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const token = new URL(request.url).searchParams.get("token") ?? "";
  const grant = await resolvePreviewGrant(token);
  if (!grant) return new Response("Not found", { status: 404 });

  const { id } = await params;
  const [asset, series] = await Promise.all([getMediaAsset(id), getStudioSeries(grant.seriesSlug)]);
  if (!asset || !series || asset.seriesSlug !== grant.seriesSlug) return new Response("Not found", { status: 404 });
  const mediaUrl = `/api/media/${asset.id}`;
  const linked = asset.kind === "cover"
    ? series.coverImage === mediaUrl
    : series.episodes
      .filter((episode) => !grant.episodeSlug || episode.slug === grant.episodeSlug)
      .some((episode) => episode.panels.some((panel) => panel.image?.src === mediaUrl));
  if (!linked) return new Response("Not found", { status: 404 });

  const object = await (await getMediaStorage()).get(asset.storageKey);
  if (!object?.body) return new Response("Not found", { status: 404 });
  return new Response(object.body, {
    headers: {
      "Content-Type": asset.mimeType,
      "Content-Length": String(asset.byteSize),
      "Cache-Control": "private, no-store, max-age=0",
      "X-Content-Type-Options": "nosniff",
      "Referrer-Policy": "no-referrer",
    },
  });
}
