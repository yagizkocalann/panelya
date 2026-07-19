import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { publicSiteUrlForCurrentRequest } from "./lib/server-site-origins";
import "./globals.css";

const geistSans = Geist({ variable: "--font-geist-sans", subsets: ["latin"] });
const geistMono = Geist_Mono({ variable: "--font-geist-mono", subsets: ["latin"] });

export async function generateMetadata(): Promise<Metadata> {
  const publicOrigin = await publicSiteUrlForCurrentRequest("/");
  return {
    metadataBase: new URL(publicOrigin),
    applicationName: "Panelya",
    title: { default: "Panelya", template: "%s" },
    description: "Özgün Türkçe dikey çizgi hikâyeleri keşfet ve oku.",
    icons: { icon: "/favicon.svg", shortcut: "/favicon.svg" },
    openGraph: { siteName: "Panelya", locale: "tr_TR", type: "website" },
    twitter: { card: "summary" },
  };
}

export const viewport: Viewport = { colorScheme: "dark", themeColor: "#08110f", width: "device-width", initialScale: 1 };

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="tr"><body className={`${geistSans.variable} ${geistMono.variable}`}>{children}</body></html>;
}
