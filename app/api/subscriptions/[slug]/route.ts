import { getPublishedSeries } from "../../../lib/content-repository";
import { assertSameOrigin, getCurrentUser, safeReturnTo } from "../../../lib/auth";
import { redirectTo } from "../../../lib/auth-http";
import { writeAudit } from "../../../lib/database";
import { toggleNewEpisodeNotifications, toggleSeriesFollow } from "../../../lib/series-subscriptions";

export async function POST(request: Request, { params }: { params: Promise<{ slug: string }> }) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const { slug } = await params;
  if (!(await getPublishedSeries(slug))) return new Response("Seri bulunamadı.", { status: 404 });
  const form = await request.formData();
  const returnTo = safeReturnTo(form.get("return_to"), `/${slug}`);
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, `/login?return_to=${encodeURIComponent(returnTo)}`);
  const action = String(form.get("action") ?? "follow");
  if (action === "notifications") {
    const state = await toggleNewEpisodeNotifications(user.id, slug);
    await writeAudit(user.id, state.notifyNewEpisodes ? "subscription.notifications_enabled" : "subscription.notifications_disabled", { seriesSlug: slug });
  } else if (action === "follow") {
    const state = await toggleSeriesFollow(user.id, slug);
    await writeAudit(user.id, state.isFollowing ? "subscription.followed" : "subscription.unfollowed", { seriesSlug: slug });
  } else {
    return new Response("Geçersiz işlem.", { status: 400 });
  }
  return redirectTo(request, returnTo);
}
