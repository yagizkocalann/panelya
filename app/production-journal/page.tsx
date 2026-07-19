import type { Metadata } from "next";
import { InfoPage } from "../components/InfoPage";

export const metadata: Metadata = { title: "Üretim Günlüğü — Panelya", alternates: { canonical: "/production-journal" } };
export default function ProductionJournalPage() {
  return <InfoPage kicker="Panelya Originals" title="Üretim günlüğü" intro="Özgün bir dikey serinin fikirden okuyucuya uzanan üretim hattını açık ve tekrarlanabilir biçimde kaydediyoruz." actions={[{ href: "/gece-vardiyasi", label: "Gece Vardiyası'nı aç", primary: true }, { href: "/about", label: "Panelya hakkında" }]} sections={[
    { title: "01 · Ürün omurgası", paragraphs: ["Keşif, seri detayı ve kesintisiz okuyucu akışı responsive olarak tamamlandı. Hesap, kütüphane ve ilerleme D1'e bağlandı."] },
    { title: "02 · Görsel yön", paragraphs: ["Gece Vardiyası için özgün bir style master üretildi. Panel üretimine geçmeden önce karakter, ışık, renk ve kadraj tutarlılığı kontrol ediliyor."] },
    { title: "03 · Yayın hattı", paragraphs: ["Studio seri, bölüm ve panel yükleme akışı D1 + R2 üzerinde çalışıyor. Yayınlanmamış içerik süreli bağlantıyla önizlenebiliyor; kaynak görsellerden 480, 768 ve 1200 px WebP varyantları kalıcı kuyrukla üretilip okuyucuya srcset üzerinden veriliyor."] },
    { title: "04 · Gelir deneyi", paragraphs: ["Ana sayfa ve seri detayındaki reklam yerleri Google'ın resmî test ağıyla localhost üzerinde doğrulanıyor; gerçek publisher veya gelir hesabı kullanılmıyor."] },
  ]} />;
}
