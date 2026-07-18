import type { ReactNode } from "react";
import Link from "next/link";
import { SiteFooter } from "./SiteFooter";
import { SiteHeader } from "./SiteHeader";

type InfoSection = { title: string; paragraphs?: string[]; items?: string[] };
type InfoAction = { href: string; label: string; primary?: boolean };

export function InfoPage({ kicker, title, intro, sections, actions, children }: { kicker: string; title: string; intro: string; sections: InfoSection[]; actions?: InfoAction[]; children?: ReactNode }) {
  return <div className="site-shell"><SiteHeader />
    <main id="main-content" className="info-main wrap">
      <header className="info-hero"><p className="section-kicker">{kicker}</p><h1>{title}</h1><p>{intro}</p>{actions && <div className="info-actions">{actions.map((action) => <Link key={action.href} className={`button ${action.primary ? "button--primary" : "button--ghost"}`} href={action.href}>{action.label}</Link>)}</div>}</header>
      {children}
      <div className="info-grid">{sections.map((section) => <section className="info-card" key={section.title}><h2>{section.title}</h2>{section.paragraphs?.map((paragraph) => <p key={paragraph}>{paragraph}</p>)}{section.items && <ul>{section.items.map((item) => <li key={item}>{item}</li>)}</ul>}</section>)}</div>
    </main><SiteFooter /></div>;
}
