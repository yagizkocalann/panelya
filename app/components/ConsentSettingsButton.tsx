"use client";

import { AD_CONSENT_OPEN_EVENT } from "../lib/ad-consent";

export function ConsentSettingsButton({ className = "consent-settings-button" }: { className?: string }) {
  return <button className={className} type="button" onClick={() => window.dispatchEvent(new Event(AD_CONSENT_OPEN_EVENT))}>Gizlilik tercihleri</button>;
}
