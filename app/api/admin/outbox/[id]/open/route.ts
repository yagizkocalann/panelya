import { NextResponse } from "next/server";
import { assertSameOrigin, getCurrentUser } from "../../../../../lib/auth";
import { redirectTo } from "../../../../../lib/auth-http";
import { getDatabase } from "../../../../../lib/database";
import { isAllowedAccountActionOrigin } from "../../../../../lib/site-origins";

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const user = await getCurrentUser();
  if (!user) return redirectTo(request, "/login?return_to=/outbox");
  if (user.role !== "admin") return new Response("Yetkisiz.", { status: 403 });
  const { id } = await params;
  const db = await getDatabase();
  const row = await db.prepare("SELECT action_url FROM notification_outbox WHERE id = ?").bind(id).first<{ action_url: string | null }>();
  if (!row?.action_url) return redirectTo(request, "/outbox");
  const destination = new URL(row.action_url);
  if (!isAllowedAccountActionOrigin(destination.origin, request) || !["/verify-email", "/reset-password", "/accept-admin-invite"].includes(destination.pathname)) return new Response("Güvensiz yönlendirme.", { status: 400 });
  await db.prepare("UPDATE notification_outbox SET status = 'opened', opened_at = ? WHERE id = ?").bind(Date.now(), id).run();
  return NextResponse.redirect(destination, 303);
}
