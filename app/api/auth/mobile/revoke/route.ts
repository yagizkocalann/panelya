import { productionAuthUnavailable } from "../../../../lib/production-auth";

export async function POST() {
  // Idempotent revoke behavior is activated with the Auth0 gateway implementation.
  return productionAuthUnavailable();
}
