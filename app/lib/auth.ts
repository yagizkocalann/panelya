import { cookies } from "next/headers";
import { getDatabase, writeAudit } from "./database";
import { currentRequestIsStudio } from "./server-site-origins";
import { isStudioRequest } from "./site-origins";

export const SESSION_COOKIE = "panelya_session";
const PASSWORD_ITERATIONS = 180_000;
export const PUBLIC_SESSION_IDLE_MS = 2 * 60 * 60 * 1000;
export const STUDIO_SESSION_IDLE_MS = 30 * 60 * 1000;
export const RECENT_AUTHENTICATION_MS = 10 * 60 * 1000;
const SESSION_ACTIVITY_WRITE_INTERVAL_MS = 5 * 60 * 1000;

export type SessionScope = "public" | "studio";

export type LocalUser = {
  id: string;
  email: string;
  displayName: string;
  role: "reader" | "admin";
  emailVerifiedAt: number | null;
  createdAt: number;
};

type UserRow = {
  id: string;
  email: string;
  display_name: string;
  role: "reader" | "admin";
  email_verified_at: number | null;
  created_at: number;
  password_hash?: string;
};

function bytesToBase64(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function base64ToBytes(value: string) {
  const binary = atob(value);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

export async function hashOpaqueToken(value: string) {
  const data = new TextEncoder().encode(value);
  return bytesToBase64(new Uint8Array(await crypto.subtle.digest("SHA-256", data)));
}

export function createOpaqueToken() {
  return bytesToBase64(crypto.getRandomValues(new Uint8Array(32))).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

export async function hashPassword(password: string) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(password), "PBKDF2", false, ["deriveBits"]);
  const derived = await crypto.subtle.deriveBits({ name: "PBKDF2", hash: "SHA-256", salt, iterations: PASSWORD_ITERATIONS }, key, 256);
  return `pbkdf2-sha256$${PASSWORD_ITERATIONS}$${bytesToBase64(salt)}$${bytesToBase64(new Uint8Array(derived))}`;
}

export async function verifyPassword(password: string, stored: string) {
  const [algorithm, iterationsText, saltText, expectedText] = stored.split("$");
  if (algorithm !== "pbkdf2-sha256" || !iterationsText || !saltText || !expectedText) return false;
  const iterations = Number(iterationsText);
  if (!Number.isInteger(iterations) || iterations < 100_000 || iterations > 500_000) return false;
  const salt = base64ToBytes(saltText);
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(password), "PBKDF2", false, ["deriveBits"]);
  const derived = new Uint8Array(await crypto.subtle.deriveBits({ name: "PBKDF2", hash: "SHA-256", salt, iterations }, key, 256));
  const expected = base64ToBytes(expectedText);
  if (derived.length !== expected.length) return false;
  let difference = 0;
  for (let index = 0; index < derived.length; index += 1) difference |= derived[index] ^ expected[index];
  return difference === 0;
}

function toUser(row: UserRow): LocalUser {
  return { id: row.id, email: row.email, displayName: row.display_name, role: row.role, emailVerifiedAt: row.email_verified_at, createdAt: row.created_at };
}

export function normalizeEmail(email: string) {
  return email.trim().toLowerCase();
}

export function validatePassword(password: string) {
  if (password.length < 10 || password.length > 128) return "Şifre 10–128 karakter olmalı.";
  if (!/[a-zA-ZçğıöşüÇĞİÖŞÜ]/.test(password) || !/[0-9]/.test(password)) return "Şifre en az bir harf ve bir rakam içermeli.";
  return null;
}

export function validateRegistration(displayName: string, email: string, password: string) {
  if (displayName.trim().length < 2 || displayName.trim().length > 40) return "Ad 2–40 karakter olmalı.";
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 160) return "Geçerli bir e-posta adresi gir.";
  return validatePassword(password);
}

export async function findUserByEmail(email: string) {
  const db = await getDatabase();
  const row = await db.prepare("SELECT id, email, display_name, role, email_verified_at, created_at FROM users WHERE email = ?")
    .bind(normalizeEmail(email)).first<UserRow>();
  return row ? toUser(row) : null;
}

export async function createUser(displayName: string, email: string, password: string, allowLocalFirstAdmin = false) {
  const db = await getDatabase();
  const normalized = normalizeEmail(email);
  const count = await db.prepare("SELECT COUNT(*) AS count FROM users").first<{ count: number }>();
  const role: LocalUser["role"] = allowLocalFirstAdmin && Number(count?.count ?? 0) === 0 ? "admin" : "reader";
  const id = crypto.randomUUID();
  const now = Date.now();
  const passwordHash = await hashPassword(password);
  await db.prepare("INSERT INTO users (id, email, display_name, password_hash, role, email_verified_at, created_at, updated_at) VALUES (?, ?, ?, ?, ?, NULL, ?, ?)")
    .bind(id, normalized, displayName.trim(), passwordHash, role, now, now)
    .run();
  await writeAudit(id, "account.registered", { role });
  return { id, email: normalized, displayName: displayName.trim(), role, emailVerifiedAt: null, createdAt: now } satisfies LocalUser;
}

export async function authenticate(email: string, password: string) {
  const db = await getDatabase();
  const row = await db.prepare("SELECT id, email, display_name, password_hash, role, email_verified_at, created_at FROM users WHERE email = ?")
    .bind(normalizeEmail(email)).first<UserRow & { password_hash: string }>();
  if (!row || !(await verifyPassword(password, row.password_hash))) return null;
  return toUser(row);
}

function idleDuration(scope: SessionScope) {
  return scope === "studio" ? STUDIO_SESSION_IDLE_MS : PUBLIC_SESSION_IDLE_MS;
}

function scopeForRequest(request: Request): SessionScope {
  return isStudioRequest(request) ? "studio" : "public";
}

async function scopeForCurrentRequest(): Promise<SessionScope> {
  return await currentRequestIsStudio() ? "studio" : "public";
}

export async function createSession(userId: string, remember: boolean, request: Request) {
  const db = await getDatabase();
  const rawToken = createOpaqueToken();
  const tokenHash = await hashOpaqueToken(rawToken);
  const now = Date.now();
  const scope = scopeForRequest(request);
  const expiresAt = now + (remember ? 30 : 1) * 24 * 60 * 60 * 1000;
  const idleExpiresAt = Math.min(expiresAt, now + idleDuration(scope));
  await db.prepare(`INSERT INTO sessions
    (token_hash, user_id, scope, remembered, expires_at, idle_expires_at, authenticated_at, last_seen_at, created_at, user_agent)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`).bind(
      tokenHash,
      userId,
      scope,
      remember ? 1 : 0,
      expiresAt,
      idleExpiresAt,
      now,
      now,
      now,
      request.headers.get("user-agent")?.slice(0, 300) ?? null,
    ).run();
  return { rawToken, expiresAt };
}

type SessionUserRow = UserRow & {
  token_hash: string;
  expires_at: number;
  idle_expires_at: number;
  last_seen_at: number;
};

export async function getUserFromToken(rawToken: string | undefined, scope: SessionScope = "public") {
  if (!rawToken) return null;
  const db = await getDatabase();
  const tokenHash = await hashOpaqueToken(rawToken);
  const row = await db.prepare(`SELECT u.id, u.email, u.display_name, u.role, u.email_verified_at, u.created_at,
      s.token_hash, s.expires_at, s.idle_expires_at, s.last_seen_at
    FROM sessions s JOIN users u ON u.id = s.user_id
    WHERE s.token_hash = ? AND s.scope = ?`).bind(tokenHash, scope).first<SessionUserRow>();
  if (!row) return null;
  const now = Date.now();
  if (row.expires_at <= now || row.idle_expires_at <= now) {
    await db.prepare("DELETE FROM sessions WHERE token_hash = ?").bind(tokenHash).run();
    return null;
  }
  if (now - row.last_seen_at >= SESSION_ACTIVITY_WRITE_INTERVAL_MS) {
    await db.prepare("UPDATE sessions SET last_seen_at = ?, idle_expires_at = ? WHERE token_hash = ?")
      .bind(now, Math.min(row.expires_at, now + idleDuration(scope)), tokenHash).run();
  }
  return toUser(row);
}

export async function getCurrentUser() {
  const cookieStore = await cookies();
  return getUserFromToken(cookieStore.get(SESSION_COOKIE)?.value, await scopeForCurrentRequest());
}

export async function hasRecentAuthentication() {
  const cookieStore = await cookies();
  const rawToken = cookieStore.get(SESSION_COOKIE)?.value;
  if (!rawToken) return false;
  const db = await getDatabase();
  const now = Date.now();
  const row = await db.prepare(`SELECT authenticated_at FROM sessions
    WHERE token_hash = ? AND scope = ? AND expires_at > ? AND idle_expires_at > ?`)
    .bind(await hashOpaqueToken(rawToken), await scopeForCurrentRequest(), now, now).first<{ authenticated_at: number }>();
  return Boolean(row && row.authenticated_at >= now - RECENT_AUTHENTICATION_MS);
}

export async function rotateCurrentSessionAfterReauthentication() {
  const cookieStore = await cookies();
  const rawToken = cookieStore.get(SESSION_COOKIE)?.value;
  if (!rawToken) return null;
  const db = await getDatabase();
  const scope = await scopeForCurrentRequest();
  const oldTokenHash = await hashOpaqueToken(rawToken);
  const current = await db.prepare(`SELECT remembered FROM sessions
    WHERE token_hash = ? AND scope = ?`).bind(oldTokenHash, scope).first<{ remembered: number }>();
  if (!current) return null;
  const now = Date.now();
  const expiresAt = now + (current.remembered ? 30 : 1) * 24 * 60 * 60 * 1000;
  const newRawToken = createOpaqueToken();
  const newTokenHash = await hashOpaqueToken(newRawToken);
  const rotated = await db.prepare(`UPDATE sessions SET token_hash = ?, expires_at = ?, idle_expires_at = ?,
    authenticated_at = ?, last_seen_at = ? WHERE token_hash = ? AND scope = ?`).bind(
      newTokenHash,
      expiresAt,
      Math.min(expiresAt, now + idleDuration(scope)),
      now,
      now,
      oldTokenHash,
      scope,
    ).run();
  if (Number(rotated.meta.changes ?? 0) !== 1) return null;
  return { rawToken: newRawToken, expiresAt };
}

export async function deleteSession(rawToken: string | undefined) {
  if (!rawToken) return;
  const db = await getDatabase();
  await db.prepare("DELETE FROM sessions WHERE token_hash = ?").bind(await hashOpaqueToken(rawToken)).run();
}

export async function getCurrentSessionHash() {
  const cookieStore = await cookies();
  const rawToken = cookieStore.get(SESSION_COOKIE)?.value;
  return rawToken ? hashOpaqueToken(rawToken) : null;
}

export async function getPasswordHash(userId: string) {
  const db = await getDatabase();
  return db.prepare("SELECT password_hash FROM users WHERE id = ?").bind(userId).first<{ password_hash: string }>();
}

export function safeReturnTo(value: FormDataEntryValue | string | null | undefined, fallback = "/account") {
  const path = typeof value === "string" ? value : "";
  return path.startsWith("/") && !path.startsWith("//") && !path.includes("\\") ? path : fallback;
}

export function safeAuthClosePath(value: FormDataEntryValue | string | null | undefined) {
  const path = safeReturnTo(value, "/");
  return ["/account", "/library", "/studio"].some((root) => path === root || path.startsWith(`${root}/`)) ? "/" : path;
}

export function assertSameOrigin(request: Request) {
  const origin = request.headers.get("origin");
  const expectedOrigin = new URL(request.url).origin;
  if (origin) {
    if (origin !== expectedOrigin) throw new Error("invalid_origin");
    return;
  }
  // Some form navigations omit Origin; Fetch Metadata still proves a same-origin browser request.
  if (request.headers.get("sec-fetch-site") !== "same-origin") throw new Error("invalid_origin");
}
