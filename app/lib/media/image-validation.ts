export const ALLOWED_IMAGE_TYPES = ["image/jpeg", "image/png", "image/webp"] as const;
export type AllowedImageType = typeof ALLOWED_IMAGE_TYPES[number];
export type MediaKind = "cover" | "panel";
export type ImageMetadata = { mimeType: AllowedImageType; width: number; height: number; byteSize: number };

const MAX_DIMENSION = 12_000;
const MAX_PIXELS = 48_000_000;
const SIZE_LIMITS: Record<MediaKind, number> = { cover: 8 * 1024 * 1024, panel: 12 * 1024 * 1024 };

function u16(bytes: Uint8Array, offset: number, little = false) { return little ? bytes[offset] | (bytes[offset + 1] << 8) : (bytes[offset] << 8) | bytes[offset + 1]; }
function u24(bytes: Uint8Array, offset: number) { return (bytes[offset] << 16) | (bytes[offset + 1] << 8) | bytes[offset + 2]; }
function u32(bytes: Uint8Array, offset: number) { return (bytes[offset] * 0x1000000) + (bytes[offset + 1] << 16) + (bytes[offset + 2] << 8) + bytes[offset + 3]; }

function pngSize(bytes: Uint8Array) {
  if (bytes.length < 24 || bytes[0] !== 137 || bytes[1] !== 80 || bytes[2] !== 78 || bytes[3] !== 71) return null;
  return { width: u32(bytes, 16), height: u32(bytes, 20) };
}

function jpegSize(bytes: Uint8Array) {
  if (bytes.length < 4 || bytes[0] !== 0xff || bytes[1] !== 0xd8) return null;
  let offset = 2;
  while (offset + 9 < bytes.length) {
    if (bytes[offset] !== 0xff) return null;
    while (bytes[offset] === 0xff) offset += 1;
    const marker = bytes[offset++];
    if (marker === 0xd9 || marker === 0xda) break;
    const length = u16(bytes, offset);
    if (length < 2 || offset + length > bytes.length) return null;
    if ((marker >= 0xc0 && marker <= 0xc3) || (marker >= 0xc5 && marker <= 0xc7) || (marker >= 0xc9 && marker <= 0xcb) || (marker >= 0xcd && marker <= 0xcf)) return { height: u16(bytes, offset + 3), width: u16(bytes, offset + 5) };
    offset += length;
  }
  return null;
}

function webpSize(bytes: Uint8Array) {
  if (bytes.length < 30 || String.fromCharCode(...bytes.slice(0, 4)) !== "RIFF" || String.fromCharCode(...bytes.slice(8, 12)) !== "WEBP") return null;
  const type = String.fromCharCode(...bytes.slice(12, 16));
  if (type === "VP8 ") return { width: u16(bytes, 26) & 0x3fff, height: u16(bytes, 28) & 0x3fff };
  if (type === "VP8L") {
    if (bytes[20] !== 0x2f) return null;
    return { width: 1 + (u16(bytes, 21) & 0x3fff), height: 1 + ((bytes[22] >> 6) | (bytes[23] << 2) | ((bytes[24] & 0x03) << 10)) };
  }
  if (type === "VP8X") return { width: 1 + u24(bytes, 24), height: 1 + u24(bytes, 27) };
  return null;
}

function dimensions(bytes: Uint8Array, type: AllowedImageType) { return type === "image/png" ? pngSize(bytes) : type === "image/jpeg" ? jpegSize(bytes) : webpSize(bytes); }

export async function inspectImage(file: File, kind: MediaKind): Promise<ImageMetadata> {
  if (!ALLOWED_IMAGE_TYPES.includes(file.type as AllowedImageType)) throw new Error("Bu dosya türü desteklenmiyor. JPEG, PNG veya WebP yükleyin.");
  if (!file.size || file.size > SIZE_LIMITS[kind]) throw new Error(kind === "cover" ? "Kapak 8 MB sınırını aşıyor." : "Panel 12 MB sınırını aşıyor.");
  const bytes = new Uint8Array(await file.arrayBuffer());
  const size = dimensions(bytes, file.type as AllowedImageType);
  if (!size || !Number.isInteger(size.width) || !Number.isInteger(size.height)) throw new Error("Görsel dosyası okunamadı veya MIME türü içeriğiyle eşleşmiyor.");
  const minimum = kind === "cover" ? { width: 320, height: 400 } : { width: 320, height: 240 };
  if (size.width < minimum.width || size.height < minimum.height) throw new Error(kind === "cover" ? "Kapak en az 320 × 400 px olmalı." : "Panel en az 320 × 240 px olmalı.");
  if (size.width > MAX_DIMENSION || size.height > MAX_DIMENSION || size.width * size.height > MAX_PIXELS) throw new Error("Görsel çözünürlüğü güvenli sınırı aşıyor.");
  return { mimeType: file.type as AllowedImageType, width: size.width, height: size.height, byteSize: file.size };
}

export async function inspectDerivative(file: File, expectedWidth: number, expectedHeight: number): Promise<ImageMetadata> {
  if (file.type !== "image/webp") throw new Error("Responsive varyant WebP olmalıdır.");
  if (!file.size || file.size > 6 * 1024 * 1024) throw new Error("Responsive varyant 6 MB sınırını aşıyor.");
  const bytes = new Uint8Array(await file.arrayBuffer());
  const size = webpSize(bytes);
  if (!size) throw new Error("Responsive WebP dosyası okunamadı.");
  if (size.width !== expectedWidth || size.height !== expectedHeight) {
    throw new Error(`Responsive varyant ${expectedWidth} × ${expectedHeight} px olmalıdır.`);
  }
  return { mimeType: "image/webp", width: size.width, height: size.height, byteSize: file.size };
}

export function extensionForMime(mimeType: AllowedImageType) { return mimeType === "image/jpeg" ? "jpg" : mimeType === "image/png" ? "png" : "webp"; }
