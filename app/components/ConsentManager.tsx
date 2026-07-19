"use client";

import { useEffect, useState, useSyncExternalStore } from "react";
import {
  AD_CONSENT_OPEN_EVENT,
  getPendingServerAdConsent,
  readAdConsent,
  subscribeAdConsent,
  writeAdConsent,
  type AdConsentChoice,
} from "../lib/ad-consent";

export function ConsentManager() {
  const savedChoice = useSyncExternalStore<"pending" | ReturnType<typeof readAdConsent>>(subscribeAdConsent, readAdConsent, getPendingServerAdConsent);
  const [openedByUser, setOpenedByUser] = useState(false);

  useEffect(() => {
    const openSettings = () => setOpenedByUser(true);
    window.addEventListener(AD_CONSENT_OPEN_EVENT, openSettings);
    return () => window.removeEventListener(AD_CONSENT_OPEN_EVENT, openSettings);
  }, []);

  function save(choice: AdConsentChoice) {
    const mustReload = savedChoice === "ads" && choice === "necessary";
    writeAdConsent(choice);
    setOpenedByUser(false);
    if (mustReload) window.location.reload();
  }

  if (savedChoice === "pending" || (savedChoice !== null && !openedByUser)) return null;

  return (
    <section className="consent-panel" aria-labelledby="consent-title" aria-describedby="consent-description">
      <div className="consent-panel__copy">
        <p className="section-kicker">Gizlilik tercihi</p>
        <h2 id="consent-title">Test reklamı iznini sen seç</h2>
        <p id="consent-description">Gerekli yerel depolama hesabını ve tercihlerini çalıştırır. Reklam izni verirsen yalnız localhost ortamında Google’ın resmî örnek test birimi yüklenir.</p>
      </div>
      <div className="consent-panel__actions">
        <button className="button button--ghost" type="button" onClick={() => save("necessary")}>Yalnız gerekli</button>
        <button className="button button--primary" type="button" onClick={() => save("ads")}>Test reklamına izin ver</button>
        {savedChoice && <button className="consent-panel__close" type="button" onClick={() => setOpenedByUser(false)} aria-label="Gizlilik tercihlerini kapat">×</button>}
      </div>
    </section>
  );
}
