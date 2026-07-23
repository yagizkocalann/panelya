export const AD_CONSENT_STORAGE_KEY = "panelya-consent-v1";
export const AD_CONSENT_CHANGED_EVENT = "panelya:ad-consent-changed";
export const AD_CONSENT_OPEN_EVENT = "panelya:ad-consent-open";

export type AdConsentChoice = "necessary" | "ads";
let memoryChoice: AdConsentChoice | null = null;

export function readAdConsent(): AdConsentChoice | null {
  try {
    const value = window.localStorage.getItem(AD_CONSENT_STORAGE_KEY);
    if (value === "necessary" || value === "ads") memoryChoice = value;
    return value === "necessary" || value === "ads" ? value : memoryChoice;
  } catch {
    return memoryChoice;
  }
}

export function writeAdConsent(choice: AdConsentChoice) {
  memoryChoice = choice;
  try {
    window.localStorage.setItem(AD_CONSENT_STORAGE_KEY, choice);
  } catch {
    // Depolama kapaliysa tercih bu sayfa oturumu boyunca yine uygulanir.
  }
  window.dispatchEvent(new CustomEvent<AdConsentChoice>(AD_CONSENT_CHANGED_EVENT, { detail: choice }));
}

export function subscribeAdConsent(onStoreChange: () => void) {
  const notify = () => onStoreChange();
  window.addEventListener(AD_CONSENT_CHANGED_EVENT, notify);
  window.addEventListener("storage", notify);
  return () => {
    window.removeEventListener(AD_CONSENT_CHANGED_EVENT, notify);
    window.removeEventListener("storage", notify);
  };
}

export function getServerAdConsent(): AdConsentChoice | null {
  return null;
}

export function getPendingServerAdConsent(): "pending" {
  return "pending";
}
