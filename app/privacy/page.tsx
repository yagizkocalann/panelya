import type { Metadata } from "next";
import { InfoPage } from "../components/InfoPage";

export const metadata: Metadata = { title: "Gizlilik — Panelya", alternates: { canonical: "/privacy" } };
export default function PrivacyPage() {
  return <InfoPage kicker="Veri ve gizlilik" title="Gizlilik bildirimi" intro="Bu metin lokal geliştirme sürümünde hangi verilerin tutulduğunu açıklar; production yayını öncesinde hukuki incelemeden geçirilecektir." sections={[
    { title: "Tuttuğumuz veriler", items: ["Hesap e-postası ve görünen ad", "Şifrelenmiş parola özeti", "Oturum, kütüphane, favori ve okuma ilerlemesi", "İletişim formundan gönderilen mesajlar", "Telif bildirimindeki başvuru sahibi, eser, URL ve hak açıklaması"] },
    { title: "Nerede tutuluyor?", paragraphs: ["Lokal sürümde veriler yalnızca bu proje için kullanılan yerel D1 veritabanında saklanır. Gerçek kullanıcı verisiyle test yapılmamalıdır."] },
    { title: "Reklam testi", paragraphs: ["Google Publisher Tag'in resmî test ağı kullanılır. Google test kreatifi yüklenirken tarayıcı Google reklam alanına bir ağ isteği yapar; Panelya publisher kimliği veya gelir hesabı kullanılmaz."] },
    { title: "Kontrolün", items: ["Profil bilgilerini değiştirebilirsin.", "Hesabını ve ilişkili yerel verileri silebilirsin.", "İletişim mesajının silinmesini iletişim sayfasından isteyebilirsin.", "Telif bildiriminin durumunu 90 günlük gizli bağlantıyla görebilirsin; production saklama ve silme süresi hukuki incelemeyle kesinleşecektir."] },
  ]} />;
}
