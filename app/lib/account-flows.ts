import { issueAccountToken } from "./account-tokens";
import { sendNotification } from "./notifications";

function actionUrl(origin: string, path: string, rawToken: string) {
  const url = new URL(path, origin);
  url.searchParams.set("token", rawToken);
  return url.toString();
}

export async function queueEmailVerification(userId: string, email: string, origin: string) {
  const token = await issueAccountToken(userId, "verify_email", email);
  await sendNotification({
    userId,
    recipient: email,
    kind: "verify_email",
    subject: "Panelya e-posta adresini doğrula",
    body: "Yerel Panelya hesabının e-posta adresini 24 saat içinde doğrula.",
    actionUrl: actionUrl(origin, "/verify-email", token),
  });
}

export async function queuePasswordReset(userId: string, email: string, origin: string) {
  const token = await issueAccountToken(userId, "password_reset", email);
  await sendNotification({
    userId,
    recipient: email,
    kind: "password_reset",
    subject: "Panelya şifre sıfırlama bağlantısı",
    body: "Bu isteği sen yaptıysan 30 dakika içinde yeni bir şifre belirle.",
    actionUrl: actionUrl(origin, "/reset-password", token),
  });
}
