import type { Metadata } from "next";
import { InfoPage } from "../components/InfoPage";

export const metadata: Metadata = { title: "Telif Bildirimi — Panelya", alternates: { canonical: "/copyright" } };
export default function CopyrightPage() {
  return <InfoPage kicker="Hak sahipliği" title="Telif bildirimi" intro="Hak sahibiysen ve Panelya'daki bir içeriğin izinsiz kullanıldığını düşünüyorsan kayıtlı inceleme sürecini başlatabilirsin." actions={[{ href: "/copyright/report", label: "Telif bildirimi gönder", primary: true }, { href: "/publishing-principles", label: "Yayın ilkelerini oku" }]} sections={[
    { title: "Gerekli bilgiler", items: ["Hak sahibinin veya yetkili temsilcinin adı ve e-postası", "Korunan eserin ayırt edici açıklaması", "İncelenecek tekil Panelya URL'si", "Varsa özgün eser veya yetki kaynağı bağlantısı", "Hak sahipliği ve iyi niyet beyanı"] },
    { title: "İnceleme süreci", paragraphs: ["Her bildirim bir referans koduyla kaydedilir. Gönderimden sonra verilen gizli bağlantı üzerinden bildirimin alındığını, incelendiğini, ek bilgi beklediğini veya sonuçlandığını görebilirsin.", "Başvuru otomatik kaldırma kararı oluşturmaz. Studio yöneticisi bildirimi ve ilgili içeriği değerlendirir; başvuru sahibine gösterilecek sonucu durum kaydına yazar."] },
    { title: "Veri ve kötüye kullanım sınırı", paragraphs: ["Formda dosya yüklemesi ve kimlik belgesi istemiyoruz. İnceleme için gerekli olmayan özel nitelikli kişisel verileri gönderme.", "Yanıltıcı veya başkasını susturmayı amaçlayan bildirimler kabul edilmez. Karşı bildirim, hukuki saklama süresi ve resmi tebligat kanalı production öncesinde hukuk danışmanıyla kesinleştirilir."] },
  ]} />;
}
