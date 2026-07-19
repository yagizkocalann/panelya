import type { Metadata } from "next";
import { InfoPage } from "../components/InfoPage";

export const metadata: Metadata = { title: "Hakkımızda — Panelya", description: "Panelya'nın ürün yaklaşımı ve özgün dikey hikâye hedefi.", alternates: { canonical: "/about" } };

export default function AboutPage() {
  return <InfoPage kicker="Panelya nedir?" title="Hikâyeler ekrana göre doğar." intro="Panelya, Türkçe özgün dikey çizgi hikâyeleri keşfetmek, takip etmek ve kesintisiz okumak için geliştirilen mobil-öncelikli bir platformdur." actions={[{ href: "/", label: "Serileri keşfet", primary: true }, { href: "/production-journal", label: "Üretim günlüğü" }]} sections={[
    { title: "Amacımız", paragraphs: ["Yerel üreticilerin telefon ekranına göre tasarlanmış hikâyelerini düzenli, hızlı ve okunabilir bir deneyimle buluşturmak."] },
    { title: "Nasıl çalışıyoruz?", items: ["Özgün veya açıkça lisanslanmış içerik", "Dikey okuma ritmine uygun bölüm tasarımı", "Okuyucu ilerlemesi ve kütüphane deneyimi", "Şeffaf yapay zekâ ve hak sahipliği kayıtları"] },
    { title: "Şu anki durum", paragraphs: ["Panelya şu anda lokal geliştirme aşamasında. Hesap, kütüphane, okuyucu, Studio ve Google test reklam akışları çalışıyor; içerik yükleme hattı sıradaki ana fazdır."] },
  ]} />;
}
