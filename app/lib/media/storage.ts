export type MediaObject = { body: ReadableStream<Uint8Array> | null; contentType?: string; etag?: string };
export interface MediaStorage { put(key: string, body: ArrayBuffer, options: { contentType: string }): Promise<void>; get(key: string): Promise<MediaObject | null>; delete(key: string): Promise<void>; }
type R2Binding = { put(key: string, value: ArrayBuffer, options?: { httpMetadata?: { contentType?: string } }): Promise<unknown>; get(key: string): Promise<{ body: ReadableStream<Uint8Array>; httpMetadata?: { contentType?: string }; etag: string } | null>; delete(key: string): Promise<void>; };

class R2MediaStorage implements MediaStorage {
  constructor(private readonly bucket: R2Binding) {}
  async put(key: string, body: ArrayBuffer, options: { contentType: string }) { await this.bucket.put(key, body, { httpMetadata: { contentType: options.contentType } }); }
  async get(key: string): Promise<MediaObject | null> { const object = await this.bucket.get(key); return object ? { body: object.body, contentType: object.httpMetadata?.contentType, etag: object.etag } : null; }
  async delete(key: string) { await this.bucket.delete(key); }
}

export async function getMediaStorage(): Promise<MediaStorage> {
  const { env } = await import("cloudflare:workers");
  if (!env.MEDIA) throw new Error("MEDIA R2 binding is unavailable.");
  return new R2MediaStorage(env.MEDIA as unknown as R2Binding);
}
