import { cookies } from "next/headers";
import { assertSameOrigin, deleteSession, safeReturnTo, SESSION_COOKIE } from "../../../lib/auth";
import { clearSessionCookie, redirectTo } from "../../../lib/auth-http";

export async function POST(request: Request) {
  try { assertSameOrigin(request); } catch { return new Response("Geçersiz istek.", { status: 403 }); }
  const form = await request.formData();
  const cookieStore = await cookies();
  await deleteSession(cookieStore.get(SESSION_COOKIE)?.value);
  const response = redirectTo(request, safeReturnTo(form.get("return_to"), "/"));
  clearSessionCookie(response);
  return response;
}
