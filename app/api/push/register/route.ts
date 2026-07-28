import { registerDeviceToken, type DevicePlatform } from "../../../lib/push-notifications";
import { consumeRateLimit, requestFingerprint } from "../../../lib/rate-limit";

const platforms = new Set<DevicePlatform>(["ios", "android"]);

// Mobil istemciler (native HTTP, tarayıcı değil) `Origin`/`Sec-Fetch-Site`
// başlıklarını göndermez — bu uç, mevcut auth-gerektirmeyen public uçlarla
// (bkz. `/api/discovery`, `/api/catalog`) AYNI nedenle `assertSameOrigin`
// kullanmaz. Kimlik doğrulaması da yok (bkz. `push-notifications.ts` doc
// yorumu — hesap/giriş olmadan "broadcast" modeli); tek koruma, token
// başına rate limit.
export async function POST(request: Request) {
  const data = await request.json().catch(() => null) as { token?: unknown; platform?: unknown } | null;
  const token = typeof data?.token === "string" ? data.token.trim() : "";
  const platform = typeof data?.platform === "string" ? data.platform : "";
  if (!token || token.length > 4096 || !platforms.has(platform as DevicePlatform)) {
    return new Response("Geçersiz istek.", { status: 400 });
  }

  const allowed = await consumeRateLimit("push-register", await requestFingerprint(request, token), 10, 60 * 60 * 1000);
  if (!allowed) return new Response("Çok fazla istek.", { status: 429 });

  await registerDeviceToken(token, platform as DevicePlatform);
  return new Response(null, { status: 204 });
}
