"use client";

import type { FormEvent } from "react";

type CatalogFilterFormProps = {
  genres: string[];
  filters: {
    query: string;
    genre: string;
    status: "ongoing" | "completed" | "";
    sort: "updated" | "rating" | "title";
  };
  pageSize: 8 | 16 | 32;
};

export function CatalogFilterForm({ genres, filters, pageSize }: CatalogFilterFormProps) {
  function applySelectFilter(event: FormEvent<HTMLFormElement>) {
    if (event.target instanceof HTMLSelectElement) event.currentTarget.requestSubmit();
  }

  return (
    <form className="catalog-filter-form" action="/catalog" method="get" role="search" onChange={applySelectFilter}>
      {pageSize !== 8 && <input type="hidden" name="size" value={pageSize} />}
      <label><span>Seri ara</span><input name="q" type="search" defaultValue={filters.query} placeholder="Başlık, üretici veya tür" maxLength={80} /></label>
      <label><span>Tür</span><select key={filters.genre || "all-genres"} name="genre" defaultValue={filters.genre} aria-describedby="catalog-filter-help"><option value="">Tüm türler</option>{genres.map((item) => <option value={item} key={item}>{item}</option>)}</select></label>
      <label><span>Durum</span><select key={filters.status || "all-statuses"} name="status" defaultValue={filters.status} aria-describedby="catalog-filter-help"><option value="">Tümü</option><option value="ongoing">Devam ediyor</option><option value="completed">Tamamlandı</option></select></label>
      <label><span>Sırala</span><select key={filters.sort} name="sort" defaultValue={filters.sort} aria-describedby="catalog-filter-help"><option value="updated">Son güncellenen</option><option value="rating">Puana göre</option><option value="title">Ada göre</option></select></label>
      <button className="button button--primary" type="submit">Ara</button>
      <p className="catalog-filter-help" id="catalog-filter-help">Tür, durum ve sıralama seçimleri otomatik uygulanır.</p>
    </form>
  );
}
