import { productionAuthUnavailable } from "../../../../lib/production-auth";

export async function POST() {
  // Fail closed until the Auth0 token gateway and provider identity mapping land.
  return productionAuthUnavailable();
}
