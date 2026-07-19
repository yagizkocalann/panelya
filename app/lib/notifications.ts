import { getDatabase } from "./database";
import { notificationDeliveryMode, type NotificationDeliveryMode } from "./runtime-config";

export type NotificationKind = "verify_email" | "password_reset" | "security_notice" | "new_episode";

export type NotificationMessage = {
  userId: string | null;
  recipient: string;
  kind: NotificationKind;
  subject: string;
  body: string;
  actionUrl?: string;
  dedupeKey?: string;
};

export interface NotificationDelivery {
  send(message: NotificationMessage): Promise<{ accepted: boolean }>;
}

export class LocalOutboxDelivery implements NotificationDelivery {
  async send(message: NotificationMessage) {
    const db = await getDatabase();
    const result = await db.prepare(`INSERT INTO notification_outbox
      (id, user_id, recipient, kind, subject, body, action_url, dedupe_key, status, created_at, opened_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'queued', ?, NULL)
      ON CONFLICT(dedupe_key) DO NOTHING`)
      .bind(crypto.randomUUID(), message.userId, message.recipient, message.kind, message.subject, message.body, message.actionUrl ?? null, message.dedupeKey ?? null, Date.now()).run();
    return { accepted: Number(result.meta.changes ?? 0) > 0 };
  }
}

export class NotificationDeliveryUnavailableError extends Error {
  constructor(public readonly mode: string) {
    super("notification_delivery_unavailable");
    this.name = "NotificationDeliveryUnavailableError";
  }
}

type DeliveryFactory = () => NotificationDelivery;
const deliveryFactories: Record<NotificationDeliveryMode, DeliveryFactory> = {
  local_outbox: () => new LocalOutboxDelivery(),
};

// Production providers add an adapter/factory here; routes and account flows remain vendor-independent.
export async function getNotificationDelivery(): Promise<NotificationDelivery> {
  const mode = await notificationDeliveryMode();
  const factory = deliveryFactories[mode as NotificationDeliveryMode];
  if (!factory) throw new NotificationDeliveryUnavailableError(mode);
  return factory();
}

export async function sendNotification(message: NotificationMessage) {
  return (await getNotificationDelivery()).send(message);
}
