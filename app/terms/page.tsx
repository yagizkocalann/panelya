import type { Metadata } from "next";
import { InfoPage } from "../components/InfoPage";

export const metadata: Metadata = { title: "Kullanım Koşulları — Panelya" };
export default function TermsPage() {
  return <InfoPage kicker="Lokal prototip" title="Kullanım koşulları" intro="Panelya'nın mevcut sürümü geliştirme ve ürün testi içindir. Bu metin production sözleşmesi değildir." sections={[
    { title: "Kabul edilen kullanım", items: ["Özellikleri lokal ortamda test etmek", "Örnek hesap ve içerik akışlarını denemek", "Hata ve ürün geri bildirimi göndermek"] },
    { title: "Kabul edilmeyen kullanım", items: ["Gerçek veya hassas kişisel veri girmek", "Telifli içerikleri izinsiz yüklemek", "Google test reklamına otomatik veya tekrarlı tıklama üretmek", "Güvenlik kontrollerini aşmaya çalışmak"] },
    { title: "İçerik hakları", paragraphs: ["Demo katalog ve Panelya Originals materyalleri yalnızca ürün geliştirme amacıyla kullanılır. Üçüncü taraf içeriği hak doğrulaması olmadan yayınlanmaz."] },
    { title: "Değişiklikler", paragraphs: ["Ürün production'a yaklaşırken hesap, ödeme, içerik lisansı ve veri koruma hükümleri ayrı bir hukuki incelemeyle güncellenecektir."] },
  ]} />;
}
