import { getDatabase } from "./database";

export type NotificationKind = "verify_email" | "password_reset" | "security_notice";

export type NotificationMessage = {
  userId: string | null;
  recipient: string;
  kind: NotificationKind;
  subject: string;
  body: string;
  actionUrl?: string;
};

export interface NotificationDelivery {
  send(message: NotificationMessage): Promise<void>;
}

class LocalOutboxDelivery implements NotificationDelivery {
  async send(message: NotificationMessage) {
    const db = await getDatabase();
    await db.prepare(`INSERT INTO notification_outbox
      (id, user_id, recipient, kind, subject, body, action_url, status, created_at, opened_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, 'queued', ?, NULL)`)
      .bind(crypto.randomUUID(), message.userId, message.recipient, message.kind, message.subject, message.body, message.actionUrl ?? null, Date.now()).run();
  }
}

// Production e-mail/SMS providers implement the same boundary; routes never depend on a vendor SDK.
export function getNotificationDelivery(): NotificationDelivery {
  return new LocalOutboxDelivery();
}

export async function sendNotification(message: NotificationMessage) {
  return getNotificationDelivery().send(message);
}
