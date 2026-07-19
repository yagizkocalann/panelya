"use client";

import { useId, useState } from "react";
import type { PublicationStatus } from "../../lib/content-repository";

const publicationLabels: Record<PublicationStatus, string> = { draft: "Taslak", published: "Yayında", archived: "Arşiv" };

export function PublicationStatusField({ currentStatus, entityLabel }: { currentStatus: PublicationStatus; entityLabel: string }) {
  const [status, setStatus] = useState<PublicationStatus>(currentStatus);
  const confirmationId = useId();
  const isPublishing = currentStatus !== "published" && status === "published";
  return <div className="publication-status-field">
    <label>Yayın durumu
      <select name="publication_status" value={status} onChange={(event) => setStatus(event.target.value as PublicationStatus)}>
        {Object.entries(publicationLabels).map(([value, label]) => <option value={value} key={value}>{label}</option>)}
      </select>
    </label>
    {isPublishing && <div className="publication-confirmation">
      <p><strong>Public yayın onayı gerekli.</strong> Bu işlem {entityLabel} okuyuculara açabilir ve bölümse takipçi bildirimlerini başlatabilir.</p>
      <label htmlFor={confirmationId}><input id={confirmationId} type="checkbox" name="publish_confirmed" value="yes" required /> Yayın özetini kontrol ettim ve public yayını onaylıyorum.</label>
    </div>}
  </div>;
}
