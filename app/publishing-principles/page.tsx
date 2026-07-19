import type { Metadata } from "next";
import { InfoPage } from "../components/InfoPage";

export const metadata: Metadata = { title: "Yayın İlkeleri — Panelya", alternates: { canonical: "/publishing-principles" } };
export default function PublishingPrinciplesPage() {
  return <InfoPage kicker="Editoryal çerçeve" title="Yayın ilkeleri" intro="Bir hikâyenin Panelya'da yer alabilmesi için karşılaması gereken temel editoryal, hukuki ve teknik kurallar." actions={[{ href: "/creators", label: "Üreticiler için süreç", primary: true }, { href: "/contact?subject=creator", label: "Başvuru gönder" }]} sections={[
    { title: "Özgünlük ve haklar", items: ["Yayın hakkı üreticide veya doğrulanmış lisans sahibinde olmalı.", "Başka platformlardan izinsiz bölüm, çeviri veya görsel kabul edilmez.", "Kaynak dosya ve üretim kayıtları talep edilebilir."] },
    { title: "Okuyucu güvenliği", items: ["Yaş ve içerik uyarıları açıkça belirtilir.", "Taciz, nefret veya kişisel veri ihlali moderasyona alınır.", "Yanıltıcı başlık ve kapak kullanılmaz."] },
    { title: "Yapay zekâ kullanımı", paragraphs: ["Yapay zekâ destekli içeriklerde model, üretim yöntemi ve insan editoryal katkısı için provenance kaydı tutulur. Var olan sanatçıların birebir stil taklidi hedeflenmez."] },
    { title: "Yayın kalitesi", items: ["Mobilde okunabilir metin", "Tutarlı panel sırası", "Doğru bölüm metadata'sı", "Web için optimize edilmiş görseller"] },
  ]} />;
}
