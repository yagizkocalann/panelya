import { mediaDerivativeDispatchMode, type MediaDerivativeDispatchMode } from "../runtime-config";

export const RESPONSIVE_WIDTHS = [480, 768, 1200] as const;
export const MEDIA_DERIVATIVE_TASK_VERSION = 1 as const;
export const MEDIA_DERIVATIVE_QUEUE_BINDING = "MEDIA_DERIVATIVE_QUEUE" as const;

export type MediaDerivativeTaskV1 = {
  version: typeof MEDIA_DERIVATIVE_TASK_VERSION;
  jobId: string;
  assetId: string;
  targetWidth: number;
  targetHeight: number;
  format: "webp";
};

type QueueProducer = {
  send(body: MediaDerivativeTaskV1): Promise<unknown>;
};

export type MediaDerivativeDispatcher = {
  mode: MediaDerivativeDispatchMode;
  sendsExternally: boolean;
  send(task: MediaDerivativeTaskV1): Promise<void>;
};

export function createMediaDerivativeTask(input: Omit<MediaDerivativeTaskV1, "version" | "format">): MediaDerivativeTaskV1 {
  return { version: MEDIA_DERIVATIVE_TASK_VERSION, format: "webp", ...input };
}

export function parseMediaDerivativeTask(value: unknown): MediaDerivativeTaskV1 | null {
  if (!value || typeof value !== "object") return null;
  const task = value as Record<string, unknown>;
  if (task.version !== MEDIA_DERIVATIVE_TASK_VERSION || task.format !== "webp") return null;
  if (typeof task.jobId !== "string" || !task.jobId || task.jobId.length > 80) return null;
  if (typeof task.assetId !== "string" || !task.assetId || task.assetId.length > 80) return null;
  if (!Number.isInteger(task.targetWidth) || Number(task.targetWidth) < 1) return null;
  if (!Number.isInteger(task.targetHeight) || Number(task.targetHeight) < 1) return null;
  return task as MediaDerivativeTaskV1;
}

export function createMediaDerivativeDispatcher(mode: string, queue?: QueueProducer): MediaDerivativeDispatcher {
  if (mode === "local_browser") {
    return { mode, sendsExternally: false, async send() {} };
  }
  if (mode === "cloudflare_queue") {
    if (!queue || typeof queue.send !== "function") {
      throw new Error(`${MEDIA_DERIVATIVE_QUEUE_BINDING} binding is unavailable.`);
    }
    return { mode, sendsExternally: true, async send(task) { await queue.send(task); } };
  }
  throw new Error("Unsupported media derivative dispatch mode.");
}

export async function getMediaDerivativeDispatcher() {
  const mode = await mediaDerivativeDispatchMode();
  if (mode === "local_browser") return createMediaDerivativeDispatcher(mode);
  if (mode !== "cloudflare_queue") return createMediaDerivativeDispatcher(mode);
  const { env } = await import("cloudflare:workers");
  const queue = (env as unknown as Record<string, unknown>)[MEDIA_DERIVATIVE_QUEUE_BINDING] as QueueProducer | undefined;
  return createMediaDerivativeDispatcher(mode, queue);
}

export async function getMediaDerivativeDispatchInfo() {
  const configuredMode = await mediaDerivativeDispatchMode();
  try {
    const dispatcher = await getMediaDerivativeDispatcher();
    return { mode: dispatcher.mode, available: true, sendsExternally: dispatcher.sendsExternally } as const;
  } catch {
    return { mode: configuredMode, available: false, sendsExternally: configuredMode === "cloudflare_queue" } as const;
  }
}
