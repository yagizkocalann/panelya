"use client";

import { useMemo, useState } from "react";

type PanelItem = { id: string; label: string; removable: boolean };

export function BulkPanelActions({ panels, seriesSlug, episodeSlug, returnTo }: { panels: PanelItem[]; seriesSlug: string; episodeSlug: string; returnTo: string }) {
  const [selected, setSelected] = useState<string[]>([]);
  const [confirmed, setConfirmed] = useState(false);
  const selectedSet = useMemo(() => new Set(selected), [selected]);
  const selectedPanels = panels.filter((panel) => selectedSet.has(panel.id));
  const canRemove = selectedPanels.length > 0 && selectedPanels.every((panel) => panel.removable) && selectedPanels.length < panels.length;
  const toggle = (id: string) => setSelected((current) => current.includes(id) ? current.filter((value) => value !== id) : [...current, id]);
  const allSelected = selected.length === panels.length;
  return <form className="bulk-panel-actions" action="/api/admin/media/manage" method="post">
    <input type="hidden" name="series_slug" value={seriesSlug} />
    <input type="hidden" name="episode_slug" value={episodeSlug} />
    <input type="hidden" name="return_to" value={returnTo} />
    <div className="bulk-panel-actions__head">
      <div><strong>Toplu panel işlemleri</strong><p>{selected.length ? `${selected.length} panel seçildi.` : "Taşımak veya bağlantısını kaldırmak için panelleri seç."}</p></div>
      <button className="button button--ghost" type="button" onClick={() => setSelected(allSelected ? [] : panels.map((panel) => panel.id))}>{allSelected ? "Seçimi temizle" : "Tümünü seç"}</button>
    </div>
    <fieldset className="bulk-panel-actions__choices">
      <legend className="sr-only">İşlem yapılacak paneller</legend>
      {panels.map((panel, index) => <label key={panel.id}>
        <input type="checkbox" name="panel_ids" value={panel.id} checked={selectedSet.has(panel.id)} onChange={() => toggle(panel.id)} />
        <span>{index + 1}. {panel.label}</span>
        {!panel.removable && <small>Yalnız taşınabilir</small>}
      </label>)}
    </fieldset>
    <div className="bulk-panel-actions__buttons">
      <button className="button button--ghost" type="submit" name="action" value="panel_move_many" formNoValidate disabled={!selected.length}>Seçilenleri yukarı taşı</button>
      <button className="button button--ghost" type="submit" name="action" value="panel_move_many_down" formNoValidate disabled={!selected.length}>Seçilenleri aşağı taşı</button>
    </div>
    <div className="bulk-panel-actions__danger">
      <label><input type="checkbox" name="bulk_confirmed" value="yes" checked={confirmed} onChange={(event) => setConfirmed(event.target.checked)} required /> Seçili Studio medya bağlantılarının bölümden ayrılacağını onaylıyorum.</label>
      <button className="button button--danger" type="submit" name="action" value="panel_remove_many" disabled={!canRemove || !confirmed}>Seçilen bağlantıları kaldır</button>
      {selectedPanels.some((panel) => !panel.removable) && <p role="status">Seçimde yalnız taşınabilen yerel panel var; kaldırmak için onu seçimden çıkar.</p>}
      {selected.length === panels.length && <p role="status">Bölümde en az bir panel kalmalıdır.</p>}
    </div>
  </form>;
}
