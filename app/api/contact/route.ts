import { assertSameOrigin } from "../../lib/auth";
import { errorRedirect, redirectTo } from "../../lib/auth-http";
import { getDatabase, writeAudit } from "../../lib/database";

const subjects = new Set(["general", "creator", "copyright", "technical"]);

export async function POST(request: Request) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const form = await request.formData();
  const name = String(form.get("name") ?? "").trim();
  const email = String(form.get("email") ?? "").trim().toLocaleLowerCase("tr");
  const subject = String(form.get("subject") ?? "general");
  const message = String(form.get("message") ?? "").trim();
  const back = `/contact?subject=${encodeURIComponent(subjects.has(subject) ? subject : "general")}`;
  if (name.length < 2 || name.length > 80) return errorRedirect(request, back, "Ad 2–80 karakter olmalı.");
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 160) return errorRedirect(request, back, "Geçerli bir e-posta gir.");
  if (!subjects.has(subject)) return errorRedirect(request, "/contact", "Geçerli bir konu seç.");
  if (message.length < 20 || message.length > 3000) return errorRedirect(request, back, "Mesaj 20–3000 karakter olmalı.");
  const db = await getDatabase();
  const now = Date.now();
  await db.prepare("INSERT INTO contact_messages (id, name, email, subject, message, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, 'new', ?, ?)")
    .bind(crypto.randomUUID(), name, email, subject, message, now, now).run();
  await writeAudit(null, "contact.received", { subject });
  return redirectTo(request, "/contact?sent=1");
}
