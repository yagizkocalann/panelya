import { getCurrentUser } from "../../../lib/auth";

export async function GET() {
  const user = await getCurrentUser();
  return Response.json({ authenticated: Boolean(user), user }, { headers: { "Cache-Control": "private, no-store" } });
}
