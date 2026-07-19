import type { Metadata } from "next";
import { InfoPage } from "../components/InfoPage";

export const metadata: Metadata = { title: "İçerik Üreticileri — Panelya", alternates: { canonical: "/creators" } };
export default function CreatorsPage() {
  return <InfoPage kicker="Panelya'da yayınla" title="İçerik üreticileri" intro="Dikey anlatı için ürettiğin özgün seri veya pilot bölümün varsa Panelya yayın sürecine başvurabilirsin." actions={[{ href: "/contact?subject=creator", label: "Proje gönder", primary: true }, { href: "/publishing-principles", label: "Yayın ilkeleri" }]} sections={[
    { title: "Başvuru paketi", items: ["Seri adı ve kısa premise", "Tür, hedef yaş ve içerik uyarıları", "En az bir pilot bölüm veya bölüm planı", "Kapak ve karakter referansları", "Hak sahipliği ve üretim yöntemi beyanı"] },
    { title: "Değerlendirme", items: ["Özgünlük ve hak kontrolü", "Dikey okuma uyumu", "Bölüm sonu ritmi ve sürdürülebilirlik", "Teknik görsel kalite"] },
    { title: "Yayın modeli", paragraphs: ["Lokal fazda yalnızca ürün içi demo ve özgün Panelya pilotları kabul edilir. Gelir paylaşımı, sözleşme ve takvim production öncesinde ayrıca tanımlanacaktır."] },
  ]} />;
}
