import Link from "next/link";

export function GenreDirectoryLinks({ genres, className }: { genres: string[]; className: string }) {
  return (
    <div className={className}>
      <Link href="/catalog">Tüm Seriler</Link>
      {genres.map((genre) => (
        <Link key={genre} href={`/catalog?genre=${encodeURIComponent(genre)}`}>{genre}</Link>
      ))}
    </div>
  );
}
