"use client";

import { useMemo, useState } from "react";
import type { MediaDerivativeJob } from "../../lib/media/derivatives";
import type { MediaDerivativeDispatchMode } from "../../lib/runtime-config";

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

type DispatchInfo = { mode: MediaDerivativeDispatchMode | string; available: boolean; sendsExternally: boolean };

export function DerivativeQueue({ jobs, dispatchInfo }: { jobs: MediaDerivativeJob[]; dispatchInfo?: DispatchInfo }) {
  const processor = dispatchInfo ?? { mode: "unknown", available: false, sendsExternally: false };
  const [items, setItems] = useState<JobState[]>(jobs);
  const [running, setRunning] = useState(false);
  const [message, setMessage] = useState("");
  const pending = useMemo(() => items.filter((job) => job.dispatchMode === "local_browser" && (job.status === "queued" || job.status === "failed")), [items]);
  const externalRetryCount = useMemo(() => items.filter((job) => job.dispatchMode === "cloudflare_queue"
    && (job.dispatchStatus === "pending" || job.dispatchStatus === "failed" || (job.dispatchStatus === "sent" && job.status === "failed"))
    && (job.status === "queued" || job.status === "failed")).length, [items]);

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
      <div><p>Kaynak dosyalar değişmeden kalır. 480, 768 ve uygun olduğunda 1200 px WebP varyantları üretilir; sonuçlar R2’ye değişmez anahtarla yazılır.</p>
        <small className="sort-note">İşlemci: {!processor.available ? "yapılandırma doğrulanamadı" : processor.sendsExternally ? "Cloudflare üretim kuyruğu" : "bu Studio tarayıcısı"}</small>
      </div>
      {pending.length > 0 && <button className="button button--primary" type="button" onClick={runQueue} disabled={running}>{running ? "Kuyruk işleniyor…" : `${pending.length} işi bu tarayıcıda işle`}</button>}
      {processor.available && processor.sendsExternally && externalRetryCount > 0 && <form action="/api/admin/media/derivatives/dispatch" method="post"><button className="button button--primary" type="submit">{externalRetryCount} işi yeniden gönder</button></form>}
    </div>
    {!processor.available && <p className="form-message form-message--error" role="alert">Üretim kuyruğu yapılandırması kullanılamıyor. İşler teslim edilmedi; ayar düzeltilene kadar yeniden gönderme açılmaz.</p>}
    {message && <p className={`form-message${message.includes("hata") ? " form-message--error" : " form-message--success"}`} role="status">{message}</p>}
    {items.length ? <div className="derivative-job-list">{items.map((job) => {
      const status = job.clientStatus === "working" ? "İşleniyor" : job.clientStatus === "done" || job.status === "completed" ? "Hazır" : job.clientStatus === "error" || job.status === "failed" ? "Hata" : job.status === "processing" ? "İşleniyor" : job.dispatchMode === "cloudflare_queue" && job.dispatchStatus === "sent" ? "Worker’a gönderildi" : job.dispatchMode === "cloudflare_queue" && job.dispatchStatus === "failed" ? "Teslim hatası" : "Kuyrukta";
      return <article key={job.id}><div><span className={`pill${status === "Hazır" ? " pill--accent" : ""}`}>{status}</span><strong>{job.filename} · {job.targetWidth} × {job.targetHeight}</strong><small>WebP · üretim denemesi {job.attempts + (job.clientStatus ? 1 : 0)} · teslim denemesi {job.dispatchAttempts}</small>{(job.clientError || job.error || job.dispatchError) && <small className="derivative-job-error">{job.clientError || job.error || job.dispatchError}</small>}</div></article>;
    })}</div> : <div className="empty-state"><strong>Kuyruk boş.</strong><p>En az 481 px genişliğinde yeni bir görsel yüklediğinde uygun responsive işler otomatik eklenir.</p></div>}
  </div>;
}
