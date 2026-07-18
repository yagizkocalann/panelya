"use client";

import { useEffect, useMemo, useRef, useState } from "react";

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

export function AdTestSlot({ placement }: { placement: string }) {
  const elementId = useMemo(() => `panelya-gpt-${placement.replace(/[^a-z0-9-]/gi, "-")}`, [placement]);
  const [status, setStatus] = useState<"loading" | "loaded" | "empty" | "blocked">("loading");
  const slotRef = useRef<GptSlot | null>(null);

  useEffect(() => {
    let active = true;
    const script = ensureGoogleTag();
    const blockedTimer = window.setTimeout(() => active && setStatus("blocked"), 8000);
    const onScriptError = () => active && setStatus("blocked");
    script.addEventListener("error", onScriptError);

    window.googletag?.cmd.push(() => {
      if (!active || !window.googletag) return;
      const pubAds = window.googletag.pubads();
      pubAds.addEventListener("slotRenderEnded", (event) => {
        if (!active || event.slot.getSlotElementId() !== elementId) return;
        window.clearTimeout(blockedTimer);
        setStatus(event.isEmpty ? "empty" : "loaded");
      });
      slotRef.current = window.googletag.defineSlot(GOOGLE_SAMPLE_AD_UNIT, [300, 250], elementId);
      if (!slotRef.current) {
        window.clearTimeout(blockedTimer);
        setStatus("empty");
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
  }, [elementId]);

  const statusText = status === "loaded" ? "Google testi yüklendi" : status === "empty" ? "Test yanıtı boş" : status === "blocked" ? "Reklam engellendi veya ağ erişimi yok" : "Google testi yükleniyor";
  return (
    <aside className="ad-test-slot ad-test-slot--google" data-ad-test-slot={placement} data-ad-status={status} aria-label="Google reklam test alanı">
      <div className="ad-test-slot__header"><span>GOOGLE GPT TEST</span><strong>{placement}</strong><small className={`ad-status ad-status--${status}`}>{statusText}</small></div>
      <div className="google-test-ad-frame"><div id={elementId} className="google-test-ad" /></div>
      <p>Google’ın resmî örnek reklam birimi · gelir ve gerçek kampanya içermez.</p>
    </aside>
  );
}
