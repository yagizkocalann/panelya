import { getDatabase } from "./database";
import { pushDeliveryMode, runtimeValue } from "./runtime-config";

// Hesap/giriş olmadan (mobilde henüz gerçek Auth0 tenant'ı yok) çalışan bir
// "broadcast" modeli: cihaz token'ı hiçbir kullanıcıya bağlanmaz, yeni
// yayınlanan HER bölüm kayıtlı TÜM cihazlara gider. Seri bazlı kişiselleştirme
// (yalnız takip edilen serilerin bildirimi) gerçek hesaplar geldiğinde ayrı
// bir iş olarak eklenir.

export type DevicePlatform = "ios" | "android";

export async function registerDeviceToken(token: string, platform: DevicePlatform) {
  const db = await getDatabase();
  const now = Date.now();
  await db.prepare(`INSERT INTO device_push_tokens (id, token, platform, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(token) DO UPDATE SET platform = excluded.platform, updated_at = excluded.updated_at`)
    .bind(crypto.randomUUID(), token, platform, now, now).run();
}

export class PushDeliveryUnavailableError extends Error {
  constructor(public readonly mode: string) {
    super("push_delivery_unavailable");
    this.name = "PushDeliveryUnavailableError";
  }
}

// --- RS256 servis hesabı JWT'si (bkz. app/lib/auth.ts'deki aynı btoa/atob
// deseni — Workers/tarayıcı ortamında taşınabilir, Buffer'a bağımlı değil) --

function bytesToBase64(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function base64ToBytes(value: string) {
  const binary = atob(value);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function toBase64Url(bytes: Uint8Array) {
  return bytesToBase64(bytes).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function pemToPkcs8(pem: string) {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  return base64ToBytes(base64);
}

export async function signServiceAccountJwt(clientEmail: string, privateKeyPem: string, now = Math.floor(Date.now() / 1000)) {
  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const encoder = new TextEncoder();
  const unsigned = `${toBase64Url(encoder.encode(JSON.stringify(header)))}.${toBase64Url(encoder.encode(JSON.stringify(claims)))}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(privateKeyPem).buffer as ArrayBuffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, encoder.encode(unsigned));
  return `${unsigned}.${toBase64Url(new Uint8Array(signature))}`;
}

async function exchangeForAccessToken(jwt: string) {
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const json = await response.json().catch(() => null) as { access_token?: string } | null;
  if (!response.ok || !json?.access_token) throw new Error("fcm_oauth_exchange_failed");
  return json.access_token;
}

export type PushBroadcastInput = {
  seriesSlug: string;
  seriesTitle: string;
  episodeSlug: string;
  episodeTitle: string;
};

export type PushBroadcastResult = { tokens: number; sent: number; failed: number };

// Production providers add a real transport here; today only "fcm" exists
// (Google Cloud Messaging). Mirrors the fail-closed factory pattern in
// `notifications.ts`: an unrecognized mode throws rather than silently
// no-op'ing, but the documented default ("disabled") is a legitimate no-op.
export async function dispatchPushBroadcast(input: PushBroadcastInput): Promise<PushBroadcastResult> {
  const mode = await pushDeliveryMode();
  if (mode === "disabled") return { tokens: 0, sent: 0, failed: 0 };
  if (mode !== "fcm") throw new PushDeliveryUnavailableError(mode);

  const projectId = await runtimeValue("FCM_PROJECT_ID");
  const clientEmail = await runtimeValue("FCM_CLIENT_EMAIL");
  const privateKeyRaw = await runtimeValue("FCM_PRIVATE_KEY");
  if (!projectId || !clientEmail || !privateKeyRaw) throw new PushDeliveryUnavailableError(mode);

  const db = await getDatabase();
  const rows = await db.prepare("SELECT id, token FROM device_push_tokens").all<{ id: string; token: string }>();
  if (rows.results.length === 0) return { tokens: 0, sent: 0, failed: 0 };

  // Secret bir tek satırda saklanırken PEM'in gerçek satır sonları `\n`
  // olarak escape edilir (bkz. .env.example yorumu); burada geri çözülür.
  const privateKey = privateKeyRaw.replaceAll("\\n", "\n");
  const jwt = await signServiceAccountJwt(clientEmail, privateKey);
  const accessToken = await exchangeForAccessToken(jwt);

  const deepLink = `panelya://series/${input.seriesSlug}/read/${input.episodeSlug}`;
  const title = `${input.seriesTitle}: ${input.episodeTitle} yayında`;
  const body = `${input.seriesTitle} serisinin yeni bölümü "${input.episodeTitle}" şimdi okunabilir.`;

  let sent = 0;
  let failed = 0;
  for (const row of rows.results) {
    try {
      const response = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
        method: "POST",
        headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          message: {
            token: row.token,
            notification: { title, body },
            data: { deepLink },
          },
        }),
      });
      if (response.ok) {
        sent += 1;
        continue;
      }
      failed += 1;
      // FCM stale/geçersiz token için UNREGISTERED veya NOT_FOUND döner —
      // bu token'ı silip listeyi kendiliğinden temiz tutuyoruz.
      const errorBody = await response.json().catch(() => null) as { error?: { status?: string } } | null;
      if (errorBody?.error?.status === "UNREGISTERED" || errorBody?.error?.status === "NOT_FOUND") {
        await db.prepare("DELETE FROM device_push_tokens WHERE id = ?").bind(row.id).run();
      }
    } catch {
      failed += 1;
    }
  }
  return { tokens: rows.results.length, sent, failed };
}
