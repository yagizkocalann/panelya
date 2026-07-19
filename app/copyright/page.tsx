import type { Metadata } from "next";
import { InfoPage } from "../components/InfoPage";

export const metadata: Metadata = { title: "Telif Bildirimi — Panelya", alternates: { canonical: "/copyright" } };
export default function CopyrightPage() {
  return <InfoPage kicker="Hak sahipliği" title="Telif bildirimi" intro="Hak sahibiysen ve Panelya'daki bir içeriğin izinsiz kullanıldığını düşünüyorsan incelenmesi için bildirim gönderebilirsin." actions={[{ href: "/contact?subject=copyright", label: "Telif bildirimi gönder", primary: true }, { href: "/publishing-principles", label: "Yayın ilkelerini oku" }]} sections={[
    { title: "Gerekli bilgiler", items: ["Hak sahibinin adı ve iletişim bilgisi", "Korunan eserin açıklaması", "İhlal edildiği düşünülen Panelya URL'si", "Hak sahipliğini destekleyen belge veya kaynak", "Bildirimin iyi niyetle yapıldığına dair beyan"] },
    { title: "İnceleme süreci", paragraphs: ["Bildirim Studio mesaj kutusuna düşer, kayıt altına alınır ve içerik yayındaysa inceleme süresince erişimi sınırlandırılabilir."] },
    { title: "Kötüye kullanım", paragraphs: ["Yanıltıcı veya başkasını susturmayı amaçlayan bildirimler kabul edilmez. Production sürecinde karşı bildirim ve itiraz prosedürü ayrıca tanımlanacaktır."] },
  ]} />;
}
