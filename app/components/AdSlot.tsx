import { resolveAdRuntimeMode } from "../lib/ad-runtime";
import { requestForCurrentHost } from "../lib/server-site-origins";
import { AdTestSlot } from "./AdTestSlot";

export async function AdSlot({ placement, showDisabled = false }: { placement: string; showDisabled?: boolean }) {
  const request = await requestForCurrentHost();
  const runtimeMode = resolveAdRuntimeMode(request.headers.get("host") ?? request.url);
  if (runtimeMode === "disabled" && !showDisabled) return null;
  return <AdTestSlot placement={placement} runtimeMode={runtimeMode} />;
}
