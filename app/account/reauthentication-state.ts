export type PendingAccountAction =
  | { kind: "email_change"; newEmail: string }
  | { kind: "account_deletion"; idempotencyKey: string };

export type PendingReauthentication = {
  requestId: string;
  codeVerifier: string;
  redirectUri: string;
  purpose: "email_change" | "account_deletion";
  action: PendingAccountAction;
  createdAt: number;
};

const STORAGE_PREFIX = "panelya.account.reauthentication.";

export function reauthenticationStorageKey(state: string) {
  return `${STORAGE_PREFIX}${state}`;
}
