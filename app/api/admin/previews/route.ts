import { NextResponse } from "next/server";
import { assertSameOrigin, getCurrentUser, hasRecentAuthentication } from "../../../lib/auth";
import { reauthenticationRedirect, redirectTo } from "../../../lib/auth-http";
import { getStudioSeries } from "../../../lib/content-repository";
import { writeAudit } from "../../../lib/database";
import { createPreviewGrant, revokePreviewGrant } from "../../../lib/preview-tokens";
import { isStudioRequest, publicSiteOrigin } from "../../../lib/site-origins";

function field(form: FormData, name: string, max = 160) {
  return String(form.get(name) ?? "").trim().slice(0, max);
}

function safeReturnTo(form: FormData) {
  const value = field(form, "return_to", 300);
  return /^\/content(?:[/?]|$)/.test(value) ? value : "/content";
}

function errorRedirect(request: Request, path: string, message: string) {
  const url = new URL(path, request.url);
  url.searchParams.set("error", message);
  return NextResponse.redirect(url, 303);
}

export async function POST(request: Request) {
  if (!isStudioRequest(request)) return new Response("Not found", { status: 404 });
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, "/login?return_to=/content");
  if (user.role !== "admin") return new Response("Yetkisiz.", { status: 403 });

  const form = await request.formData();
  const returnTo = safeReturnTo(form);
  if (!(await hasRecentAuthentication())) return reauthenticationRedirect(request, returnTo);
  const seriesSlug = field(form, "series_slug", 80);
  const episodeSlug = field(form, "episode_slug", 80) || null;
  const series = seriesSlug ? await getStudioSeries(seriesSlug) : null;
  if (!series) return errorRedirect(request, returnTo, "Seri bulunamadı.");
  if (episodeSlug && !series.episodes.some((episode) => episode.slug === episodeSlug)) {
    return errorRedirect(request, returnTo, "Bölüm bulunamadı.");
  }

  const action = field(form, "action", 20);
  if (action === "revoke") {
    const grantId = field(form, "grant_id", 80);
    const revoked = await revokePreviewGrant(grantId, seriesSlug, episodeSlug);
    if (!revoked) return errorRedirect(request, returnTo, "Önizleme bağlantısı zaten kapalı veya bulunamadı.");
    await writeAudit(user.id, "preview.revoked", { grantId, seriesSlug, episodeSlug });
    const url = new URL(returnTo, request.url);
    url.searchParams.set("preview", "revoked");
    return NextResponse.redirect(url, 303);
  }

  if (action !== "create") return errorRedirect(request, returnTo, "Önizleme işlemi tanınmıyor.");
  const { rawToken, grant } = await createPreviewGrant(user.id, seriesSlug, episodeSlug);
  await writeAudit(user.id, "preview.created", {
    grantId: grant.id,
    seriesSlug,
    episodeSlug,
    expiresAt: grant.expiresAt,
  });
  return NextResponse.redirect(new URL(`/preview/${rawToken}`, `${publicSiteOrigin(request)}/`), 303);
}
