"use client";

import Link from "next/link";
import { useEffect, useRef } from "react";

export function GenreMenu({ genres }: { genres: string[] }) {
  const detailsRef = useRef<HTMLDetailsElement>(null);

  useEffect(() => {
    function closeWhenOutside(event: PointerEvent) {
      if (detailsRef.current?.open && event.target instanceof Node && !detailsRef.current.contains(event.target)) {
        detailsRef.current.open = false;
      }
    }
    function closeWithEscape(event: KeyboardEvent) {
      if (event.key === "Escape" && detailsRef.current?.open) {
        detailsRef.current.open = false;
        detailsRef.current.querySelector("summary")?.focus();
      }
    }
    document.addEventListener("pointerdown", closeWhenOutside);
    document.addEventListener("keydown", closeWithEscape);
    return () => {
      document.removeEventListener("pointerdown", closeWhenOutside);
      document.removeEventListener("keydown", closeWithEscape);
    };
  }, []);

  function closeAfterNavigation() {
    if (detailsRef.current) detailsRef.current.open = false;
  }

  return (
    <details className="genre-menu" ref={detailsRef}>
      <summary><span>Keşfet</span><strong>Katalog ve türler</strong></summary>
      <div className="genre-menu__panel" onClick={closeAfterNavigation}>
        <Link href="/catalog">Tüm seriler</Link>
        <Link href="/new-series">Yeni seriler</Link>
        {genres.map((genre) => <Link key={genre} href={`/catalog?genre=${encodeURIComponent(genre)}`}>{genre}</Link>)}
      </div>
    </details>
  );
}
