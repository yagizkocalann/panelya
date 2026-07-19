import { createOpaqueToken, hashOpaqueToken, normalizeEmail } from "./auth";
import { getDatabase } from "./database";

export const COPYRIGHT_STATUS_ACCESS_MS = 90 * 24 * 60 * 60 * 1000;

export const COPYRIGHT_NOTICE_STATUSES = [
  "submitted",
  "under_review",
  "needs_information",
  "action_taken",
  "rejected",
] as const;

export type CopyrightNoticeStatus = (typeof COPYRIGHT_NOTICE_STATUSES)[number];

export type CopyrightNotice = {
  id: string;
  referenceCode: string;
  claimantName: string;
  claimantEmail: string;
  claimantRole: "rights_holder" | "authorized_representative";
  workDescription: string;
  originalWorkUrl: string | null;
  contentUrl: string;
  rightsExplanation: string;
  status: CopyrightNoticeStatus;
  publicResponse: string | null;
  accessExpiresAt: number;
  resolvedAt: number | null;
  createdAt: number;
  updatedAt: number;
};

type CopyrightNoticeRow = {
  id: string;
  reference_code: string;
  claimant_name: string;
  claimant_email: string;
  claimant_role: CopyrightNotice["claimantRole"];
  work_description: string;
  original_work_url: string | null;
  content_url: string;
  rights_explanation: string;
  status: CopyrightNoticeStatus;
  public_response: string | null;
  access_expires_at: number;
  resolved_at: number | null;
  created_at: number;
  updated_at: number;
};

function mapNotice(row: CopyrightNoticeRow): CopyrightNotice {
  return {
    id: row.id,
    referenceCode: row.reference_code,
    claimantName: row.claimant_name,
    claimantEmail: row.claimant_email,
    claimantRole: row.claimant_role,
    workDescription: row.work_description,
    originalWorkUrl: row.original_work_url,
    contentUrl: row.content_url,
    rightsExplanation: row.rights_explanation,
    status: row.status,
    publicResponse: row.public_response,
    accessExpiresAt: Number(row.access_expires_at),
    resolvedAt: row.resolved_at === null ? null : Number(row.resolved_at),
    createdAt: Number(row.created_at),
    updatedAt: Number(row.updated_at),
  };
}

function referenceCode(id: string, now: number) {
  return `PNY-${new Date(now).getUTCFullYear()}-${id.replaceAll("-", "").slice(0, 8).toUpperCase()}`;
}

export async function createCopyrightNotice(input: {
  claimantName: string;
  claimantEmail: string;
  claimantRole: CopyrightNotice["claimantRole"];
  workDescription: string;
  originalWorkUrl: string | null;
  contentUrl: string;
  rightsExplanation: string;
}) {
  const db = await getDatabase();
  const id = crypto.randomUUID();
  const rawAccessToken = createOpaqueToken();
  const now = Date.now();
  const accessExpiresAt = now + COPYRIGHT_STATUS_ACCESS_MS;
  const code = referenceCode(id, now);
  await db.prepare(`INSERT INTO copyright_notices (
    id, reference_code, access_token_hash, claimant_name, claimant_email, claimant_role,
    work_description, original_work_url, content_url, rights_explanation, status,
    access_expires_at, created_at, updated_at
  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'submitted', ?, ?, ?)`).bind(
    id,
    code,
    await hashOpaqueToken(rawAccessToken),
    input.claimantName,
    normalizeEmail(input.claimantEmail),
    input.claimantRole,
    input.workDescription,
    input.originalWorkUrl,
    input.contentUrl,
    input.rightsExplanation,
    accessExpiresAt,
    now,
    now,
  ).run();
  return { id, referenceCode: code, rawAccessToken, accessExpiresAt };
}

export async function getCopyrightNoticeByAccessToken(rawAccessToken: string) {
  if (rawAccessToken.length < 40 || rawAccessToken.length > 200) return null;
  const db = await getDatabase();
  const row = await db.prepare(`SELECT id, reference_code, claimant_name, claimant_email, claimant_role,
    work_description, original_work_url, content_url, rights_explanation, status, public_response,
    access_expires_at, resolved_at, created_at, updated_at
    FROM copyright_notices WHERE access_token_hash = ? AND access_expires_at > ?`)
    .bind(await hashOpaqueToken(rawAccessToken), Date.now()).first<CopyrightNoticeRow>();
  return row ? mapNotice(row) : null;
}

export async function listCopyrightNotices() {
  const db = await getDatabase();
  const rows = await db.prepare(`SELECT id, reference_code, claimant_name, claimant_email, claimant_role,
    work_description, original_work_url, content_url, rights_explanation, status, public_response,
    access_expires_at, resolved_at, created_at, updated_at
    FROM copyright_notices
    ORDER BY CASE status
      WHEN 'submitted' THEN 0
      WHEN 'needs_information' THEN 1
      WHEN 'under_review' THEN 2
      ELSE 3 END, created_at DESC`).all<CopyrightNoticeRow>();
  return rows.results.map(mapNotice);
}
