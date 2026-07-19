import Link from "next/link";

export function recentAuthenticationHref(returnTo: string) {
  return `/reauthenticate?return_to=${encodeURIComponent(returnTo)}`;
}

export function RecentAuthenticationNotice({ returnTo }: { returnTo: string }) {
  return <aside className="studio-notice"><strong>Yakın zamanda doğrulama gerekli:</strong> Bu ekrandaki hassas işlemler için şifreni son 10 dakika içinde doğrulamalısın. <Link className="inline-link" href={recentAuthenticationHref(returnTo)}>Şimdi doğrula →</Link></aside>;
}
