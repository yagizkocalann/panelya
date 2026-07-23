"use client";

import { useEffect, useMemo, useRef, useState, useSyncExternalStore } from "react";
import { getServerAdConsent, readAdConsent, subscribeAdConsent } from "../lib/ad-consent";
import type { AdRuntimeMode } from "../lib/ad-runtime";

type GptSlot = {
  addService(service: GptPubAds): GptSlot;
  getSlotElementId(): string;
};

type GptRenderEvent = { slot: GptSlot; isEmpty: boolean };
type GptPubAds = { addEventListener(event: "slotRenderEnded", listener: (event: GptRenderEvent) => void): void };
type GoogleTag = {
  cmd: { push(command: () => void): void };
  defineSlot(path: string, size: [number, number], elementId: string): GptSlot | null;
  pubads(): GptPubAds;
  enableServices(): void;
  display(elementId: string): void;
  destroySlots(slots?: GptSlot[]): boolean;
};

declare global {
  interface Window {
    googletag?: GoogleTag;
    __panelyaGptEnabled?: boolean;
  }
}

const GOOGLE_GPT_SRC = "https://securepubads.g.doubleclick.net/tag/js/gpt.js";
const GOOGLE_SAMPLE_AD_UNIT = "/6355419/Travel/Europe/France/Paris";

function ensureGoogleTag() {
  window.googletag ??= { cmd: [] } as unknown as GoogleTag;
  let script = document.querySelector<HTMLScriptElement>("script[data-panelya-google-gpt]");
  if (!script) {
    script = document.createElement("script");
    script.src = GOOGLE_GPT_SRC;
    script.async = true;
    script.crossOrigin = "anonymous";
    script.dataset.panelyaGoogleGpt = "true";
    document.head.appendChild(script);
  }
  return script;
}

type AdStatus = "consent_required" | "consent_denied" | "disabled" | "loading" | "loaded" | "empty" | "blocked";

export function AdTestSlot({ placement, runtimeMode }: { placement: string; runtimeMode: AdRuntimeMode }) {
  const elementId = useMemo(() => `panelya-gpt-${placement.replace(/[^a-z0-9-]/gi, "-")}`, [placement]);
  const consent = useSyncExternalStore(subscribeAdConsent, readAdConsent, getServerAdConsent);
  const [networkStatus, setNetworkStatus] = useState<AdStatus>("loading");
  const slotRef = useRef<GptSlot | null>(null);

  useEffect(() => {
    if (runtimeMode === "disabled" || consent !== "ads") return;

    let active = true;
    const script = ensureGoogleTag();
    const blockedTimer = window.setTimeout(() => active && setNetworkStatus("blocked"), 8000);
    const onScriptError = () => active && setNetworkStatus("blocked");
    script.addEventListener("error", onScriptError);

    window.googletag?.cmd.push(() => {
      if (!active || !window.googletag) return;
      const pubAds = window.googletag.pubads();
      pubAds.addEventListener("slotRenderEnded", (event) => {
        if (!active || event.slot.getSlotElementId() !== elementId) return;
        window.clearTimeout(blockedTimer);
        setNetworkStatus(event.isEmpty ? "empty" : "loaded");
      });
      slotRef.current = window.googletag.defineSlot(GOOGLE_SAMPLE_AD_UNIT, [300, 250], elementId);
      if (!slotRef.current) {
        window.clearTimeout(blockedTimer);
        setNetworkStatus("empty");
        return;
      }
      slotRef.current.addService(pubAds);
      if (!window.__panelyaGptEnabled) {
        window.googletag.enableServices();
        window.__panelyaGptEnabled = true;
      }
      window.googletag.display(elementId);
    });

    return () => {
      active = false;
      window.clearTimeout(blockedTimer);
      script.removeEventListener("error", onScriptError);
      if (slotRef.current && window.googletag) window.googletag.destroySlots([slotRef.current]);
      slotRef.current = null;
    };
  }, [consent, elementId, runtimeMode]);

  const status: AdStatus = runtimeMode === "disabled" ? "disabled" : consent === null ? "consent_required" : consent === "necessary" ? "consent_denied" : networkStatus;
  const statusText = status === "loaded" ? "Google testi yüklendi" : status === "empty" ? "Test yanıtı boş" : status === "blocked" ? "Reklam engellendi veya ağ erişimi yok" : status === "consent_denied" ? "Reklam izni verilmedi" : status === "consent_required" ? "Reklam izni bekleniyor" : status === "disabled" ? "Bu ortamda reklam kapalı" : "Google testi yükleniyor";
  const canRenderGoogle = runtimeMode === "google_test" && consent === "ads";
  return (
    <aside className="ad-test-slot ad-test-slot--google" data-ad-test-slot={placement} data-ad-status={status} aria-label="Google reklam test alanı">
      <div className="ad-test-slot__header"><span>GOOGLE GPT TEST</span><strong>{placement}</strong><small className={`ad-status ad-status--${status}`}>{statusText}</small></div>
      {canRenderGoogle ? <div className="google-test-ad-frame"><div id={elementId} className="google-test-ad" /></div> : <div className="ad-consent-placeholder"><strong>{statusText}</strong><p>{status === "disabled" ? "Canlı reklam bağlantısı yapılandırılmadı; harici istek gönderilmiyor." : "Tercihini alt bilgideki Gizlilik tercihleri düğmesinden değiştirebilirsin."}</p></div>}
      <p>Google’ın resmî örnek reklam birimi · gelir ve gerçek kampanya içermez.</p>
    </aside>
  );
}
