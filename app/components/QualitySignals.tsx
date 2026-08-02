"use client";

import { useEffect } from "react";
import {
  QUALITY_EVENT_SCHEMA_VERSION,
  sanitizeQualityPath,
  type QualityEvent,
  type QualityMetricName,
  type QualityRating,
} from "../lib/quality-observability";

type LayoutShiftEntry = PerformanceEntry & { hadRecentInput?: boolean; value?: number };
type EventTimingEntry = PerformanceEntry & { interactionId?: number };

function privacySignalEnabled() {
  const navigatorWithGpc = navigator as Navigator & { globalPrivacyControl?: boolean };
  return navigatorWithGpc.globalPrivacyControl === true || navigator.doNotTrack === "1";
}

export function reportQualityEvent(event: Omit<QualityEvent, "schemaVersion" | "path">) {
  if (privacySignalEnabled()) return;
  const payload: QualityEvent = {
    schemaVersion: QUALITY_EVENT_SCHEMA_VERSION,
    path: sanitizeQualityPath(window.location.pathname),
    ...event,
  };
  const body = JSON.stringify(payload);
  void fetch("/api/quality", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body,
    credentials: "omit",
    keepalive: true,
  }).catch(() => undefined);
}

function ratingFor(name: QualityMetricName, value: number): QualityRating {
  const limits: Record<QualityMetricName, [number, number]> = {
    CLS: [0.1, 0.25],
    FCP: [1_800, 3_000],
    INP: [200, 500],
    LCP: [2_500, 4_000],
    TTFB: [800, 1_800],
  };
  const [good, poor] = limits[name];
  return value <= good ? "good" : value <= poor ? "needs-improvement" : "poor";
}

export function QualitySignals() {
  useEffect(() => {
    if (privacySignalEnabled() || typeof PerformanceObserver === "undefined") return;

    const latest = new Map<QualityMetricName, number>();
    const sent = new Set<QualityMetricName>();
    const observers: PerformanceObserver[] = [];

    const sendMetric = (name: QualityMetricName, value: number) => {
      if (sent.has(name) || !Number.isFinite(value) || value < 0) return;
      sent.add(name);
      reportQualityEvent({ kind: "web_vital", name, value: Math.round(value * 1_000) / 1_000, rating: ratingFor(name, value) });
    };

    const observe = (type: string, callback: (entries: PerformanceEntry[]) => void, options?: PerformanceObserverInit) => {
      try {
        const observer = new PerformanceObserver((list) => callback(list.getEntries()));
        observer.observe(options ?? { type, buffered: true });
        observers.push(observer);
      } catch {
        // Desteklenmeyen tarayici gozlem turu sessizce atlanir.
      }
    };

    const navigation = performance.getEntriesByType("navigation")[0] as PerformanceNavigationTiming | undefined;
    if (navigation) latest.set("TTFB", Math.max(0, navigation.responseStart));
    observe("paint", (entries) => {
      const fcp = entries.find((entry) => entry.name === "first-contentful-paint");
      if (fcp) latest.set("FCP", fcp.startTime);
    });
    observe("largest-contentful-paint", (entries) => {
      const lcp = entries.at(-1);
      if (lcp) latest.set("LCP", lcp.startTime);
    });
    let cls = 0;
    observe("layout-shift", (entries) => {
      for (const entry of entries as LayoutShiftEntry[]) if (!entry.hadRecentInput) cls += entry.value ?? 0;
      latest.set("CLS", cls);
    });
    observe("event", (entries) => {
      for (const entry of entries as EventTimingEntry[]) {
        if ((entry.interactionId ?? 0) > 0) latest.set("INP", Math.max(latest.get("INP") ?? 0, entry.duration));
      }
    }, { type: "event", buffered: true, durationThreshold: 40 });

    const onError = () => reportQualityEvent({ kind: "client_error", name: "global_error" });
    const onUnhandledRejection = () => reportQualityEvent({ kind: "client_error", name: "unhandled_rejection" });
    window.addEventListener("error", onError);
    window.addEventListener("unhandledrejection", onUnhandledRejection);

    const flush = () => {
      for (const [name, value] of latest) sendMetric(name, value);
    };
    const onVisibility = () => {
      if (document.visibilityState === "hidden") flush();
    };
    document.addEventListener("visibilitychange", onVisibility);
    window.addEventListener("pagehide", flush);

    return () => {
      flush();
      for (const observer of observers) observer.disconnect();
      window.removeEventListener("error", onError);
      window.removeEventListener("unhandledrejection", onUnhandledRejection);
      document.removeEventListener("visibilitychange", onVisibility);
      window.removeEventListener("pagehide", flush);
    };
  }, []);

  return null;
}
