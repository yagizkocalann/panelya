import { getCurrentUser } from "../../../lib/auth";
import { auth0ErrorResponse, auth0GatewayConfig, userFromBearerToken } from "../../../lib/auth0-runtime";

export async function GET(request: Request) {
  let user;
  if (request.headers.has("authorization")) {
    const config = await auth0GatewayConfig();
    if (!config) return auth0ErrorResponse(new Error("auth0_unavailable"));
    try {
      user = await userFromBearerToken(request, config);
    } catch (error) {
      return auth0ErrorResponse(error);
    }
  } else {
    user = await getCurrentUser();
  }
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
