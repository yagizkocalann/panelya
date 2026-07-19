import { getCurrentUser } from "../../../lib/auth";

export async function GET() {
  const user = await getCurrentUser();
  return Response.json(
    {
      schemaVersion: "1.0",
      authenticated: Boolean(user),
      user: user ? {
        id: user.id,
        displayName: user.displayName,
        email: user.email,
        emailVerified: Boolean(user.emailVerifiedAt),
        role: user.role,
      } : null,
    },
    { headers: { "Cache-Control": "private, no-store" } },
  );
}
