"use client";

import { useMemo, useState } from "react";
import type { MediaDerivativeJob } from "../../lib/media/derivatives";

type JobState = MediaDerivativeJob & { clientStatus?: "working" | "done" | "error"; clientError?: string };

function canvasBlob(canvas: HTMLCanvasElement) {
  return new Promise<Blob>((resolve, reject) => canvas.toBlob(
    (blob) => blob ? resolve(blob) : reject(new Error("Tarayıcı WebP çıktısı üretemedi.")),
    "image/webp",
    0.82,
  ));
}

async function processJob(job: MediaDerivativeJob) {
  const source = await fetch(`/api/admin/media/${job.assetId}`, { credentials: "same-origin", cache: "no-store" });
  if (!source.ok) throw new Error("Kaynak görsel alınamadı.");
  const bitmap = await createImageBitmap(await source.blob());
  try {
    const canvas = document.createElement("canvas");
    canvas.width = job.targetWidth;
    canvas.height = job.targetHeight;
    const context = canvas.getContext("2d", { alpha: true });
    if (!context) throw new Error("Tarayıcı görsel işleme yüzeyi açılamadı.");
    context.imageSmoothingEnabled = true;
    context.imageSmoothingQuality = "high";
    context.drawImage(bitmap, 0, 0, job.targetWidth, job.targetHeight);
    const blob = await canvasBlob(canvas);
    const form = new FormData();
    form.set("job_id", job.id);
    form.set("file", new File([blob], `${job.assetId}-${job.targetWidth}w.webp`, { type: "image/webp" }));
    const response = await fetch("/api/admin/media/derivatives", { method: "POST", credentials: "same-origin", body: form });
    const result = await response.json() as { message?: string };
    if (!response.ok) throw new Error(result.message || "Responsive varyant kaydedilemedi.");
  } finally {
    bitmap.close();
  }
}

export function DerivativeQueue({ jobs }: { jobs: MediaDerivativeJob[] }) {
  const [items, setItems] = useState<JobState[]>(jobs);
  const [running, setRunning] = useState(false);
  const [message, setMessage] = useState("");
  const pending = useMemo(() => items.filter((job) => job.status === "queued" || job.status === "failed"), [items]);

  async function runQueue() {
    setRunning(true);
    setMessage("");
    let failures = 0;
    for (const job of pending) {
      setItems((current) => current.map((item) => item.id === job.id ? { ...item, clientStatus: "working", clientError: undefined } : item));
      try {
        await processJob(job);
        setItems((current) => current.map((item) => item.id === job.id ? { ...item, status: "completed", clientStatus: "done" } : item));
      } catch (error) {
        failures += 1;
        const detail = error instanceof Error ? error.message : "İşlenemedi.";
        setItems((current) => current.map((item) => item.id === job.id ? { ...item, status: "failed", clientStatus: "error", clientError: detail } : item));
      }
    }
    setRunning(false);
    setMessage(failures ? `${failures} iş hata verdi; ayrıntılar aşağıda.` : "Tüm responsive varyantlar hazırlandı.");
  }

  return <div className="derivative-queue">
    <div className="derivative-queue__summary">
      <p>Kaynak dosyalar değişmeden kalır. Yerel işlemci 480, 768 ve uygun olduğunda 1200 px WebP varyantları üretir; sonuçlar R2’ye değişmez anahtarla yazılır.</p>
      {pending.length > 0 && <button className="button button--primary" type="button" onClick={runQueue} disabled={running}>{running ? "Kuyruk işleniyor…" : `${pending.length} işi bu tarayıcıda işle`}</button>}
    </div>
    {message && <p className={`form-message${message.includes("hata") ? " form-message--error" : " form-message--success"}`} role="status">{message}</p>}
    {items.length ? <div className="derivative-job-list">{items.map((job) => {
      const status = job.clientStatus === "working" ? "İşleniyor" : job.clientStatus === "done" || job.status === "completed" ? "Hazır" : job.clientStatus === "error" || job.status === "failed" ? "Hata" : job.status === "processing" ? "İşleniyor" : "Kuyrukta";
      return <article key={job.id}><div><span className={`pill${status === "Hazır" ? " pill--accent" : ""}`}>{status}</span><strong>{job.filename} · {job.targetWidth} × {job.targetHeight}</strong><small>WebP · deneme {job.attempts + (job.clientStatus ? 1 : 0)}</small>{(job.clientError || job.error) && <small className="derivative-job-error">{job.clientError || job.error}</small>}</div></article>;
    })}</div> : <div className="empty-state"><strong>Kuyruk boş.</strong><p>En az 481 px genişliğinde yeni bir görsel yüklediğinde uygun responsive işler otomatik eklenir.</p></div>}
  </div>;
}
