import { assertSameOrigin, getCurrentUser } from "../../../lib/auth";
import { errorRedirect, redirectTo } from "../../../lib/auth-http";
import { getDatabase, writeAudit } from "../../../lib/database";

export async function POST(request: Request) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, "/login?return_to=/account");
  const form = await request.formData();
  const displayName = String(form.get("display_name") ?? "").trim();
  if (displayName.length < 2 || displayName.length > 40) return errorRedirect(request, "/account", "Ad 2–40 karakter olmalı.");
  try {
    const db = await getDatabase();
    await db.prepare("UPDATE users SET display_name = ?, updated_at = ? WHERE id = ?").bind(displayName, Date.now(), user.id).run();
    await writeAudit(user.id, "account.profile_updated");
    return redirectTo(request, "/account?saved=profile");
  } catch {
    return errorRedirect(request, "/account", "Profil güncellenemedi.");
  }
}
