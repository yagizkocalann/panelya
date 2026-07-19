import { assertSameOrigin } from "../../lib/auth";
import { errorRedirect, redirectTo } from "../../lib/auth-http";
import { createCopyrightNotice } from "../../lib/copyright-notices";
import { getPublishedSeries } from "../../lib/content-repository";
import { writeAudit } from "../../lib/database";
import { consumeRateLimit, requestFingerprint } from "../../lib/rate-limit";

function parseHttpUrl(value: string) {
  if (!value) return null;
  try {
    const url = new URL(value);
    return url.protocol === "http:" || url.protocol === "https:" ? url : null;
  } catch {
    return null;
  }
}

async function isPanelyaContentUrl(request: Request, value: string) {
  const candidate = parseHttpUrl(value);
  const current = new URL(request.url);
  if (!candidate || candidate.host !== current.host || candidate.username || candidate.password) return null;
  let segments: string[];
  try { segments = candidate.pathname.split("/").filter(Boolean).map(decodeURIComponent); } catch { return null; }
  if (segments.length < 1 || segments.length > 2) return null;
  const series = await getPublishedSeries(segments[0]);
  if (!series || (segments[1] && !series.episodes.some((episode) => episode.slug === segments[1]))) return null;
  candidate.hash = "";
  return candidate.toString();
}

export async function POST(request: Request) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const form = await request.formData();
  const claimantName = String(form.get("claimant_name") ?? "").trim();
  const claimantEmail = String(form.get("claimant_email") ?? "").trim().toLocaleLowerCase("tr");
  const claimantRoleInput = String(form.get("claimant_role") ?? "");
  const workDescription = String(form.get("work_description") ?? "").trim();
  const originalWorkUrlInput = String(form.get("original_work_url") ?? "").trim();
  const contentUrlInput = String(form.get("content_url") ?? "").trim();
  const rightsExplanation = String(form.get("rights_explanation") ?? "").trim();
  const goodFaith = form.get("good_faith") === "yes";
  const authorized = form.get("authorized") === "yes";
  const honeypot = String(form.get("website") ?? "").trim();
  const back = "/copyright/report";

  if (honeypot) return redirectTo(request, "/copyright?received=1");
  if (claimantName.length < 2 || claimantName.length > 100) return errorRedirect(request, back, "Ad veya unvan 2–100 karakter olmalı.");
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(claimantEmail) || claimantEmail.length > 160) return errorRedirect(request, back, "Geçerli bir e-posta gir.");
  if (claimantRoleInput !== "rights_holder" && claimantRoleInput !== "authorized_representative") return errorRedirect(request, back, "Geçerli bir başvuru sıfatı seç.");
  if (workDescription.length < 20 || workDescription.length > 1500) return errorRedirect(request, back, "Eser açıklaması 20–1500 karakter olmalı.");
  if (originalWorkUrlInput.length > 1000 || contentUrlInput.length > 1000) return errorRedirect(request, back, "Bağlantı 1000 karakteri aşamaz.");
  const originalWorkUrl = originalWorkUrlInput ? parseHttpUrl(originalWorkUrlInput)?.toString() ?? null : null;
  if (originalWorkUrlInput && !originalWorkUrl) return errorRedirect(request, back, "Özgün eser bağlantısı geçerli bir HTTP veya HTTPS adresi olmalı.");
  const contentUrl = await isPanelyaContentUrl(request, contentUrlInput);
  if (!contentUrl) return errorRedirect(request, back, "İncelenecek içerik bağlantısı bu Panelya sitesine ait geçerli bir adres olmalı.");
  if (rightsExplanation.length < 20 || rightsExplanation.length > 2000) return errorRedirect(request, back, "Hak sahipliği açıklaması 20–2000 karakter olmalı.");
  if (!goodFaith || !authorized) return errorRedirect(request, back, "İki doğruluk beyanını da onaylamalısın.");

  const allowed = await consumeRateLimit("copyright-notice", await requestFingerprint(request, claimantEmail), 3, 24 * 60 * 60 * 1000);
  if (!allowed) return errorRedirect(request, back, "Şu anda yeni bildirim alınamıyor veya günlük sınır aşıldı. Daha sonra tekrar dene.");

  const notice = await createCopyrightNotice({
    claimantName,
    claimantEmail,
    claimantRole: claimantRoleInput,
    workDescription,
    originalWorkUrl,
    contentUrl,
    rightsExplanation,
  });
  await writeAudit(null, "copyright.received", { noticeId: notice.id });
  return redirectTo(request, `/copyright/status/${encodeURIComponent(notice.rawAccessToken)}?submitted=1`);
}
