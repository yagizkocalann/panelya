import type { Metadata } from "next";
import { InfoPage } from "../components/InfoPage";

export const metadata: Metadata = { title: "Üretim Günlüğü — Panelya" };
export default function ProductionJournalPage() {
  return <InfoPage kicker="Panelya Originals" title="Üretim günlüğü" intro="Özgün bir dikey serinin fikirden okuyucuya uzanan üretim hattını açık ve tekrarlanabilir biçimde kaydediyoruz." actions={[{ href: "/gece-vardiyasi", label: "Gece Vardiyası'nı aç", primary: true }, { href: "/about", label: "Panelya hakkında" }]} sections={[
    { title: "01 · Ürün omurgası", paragraphs: ["Keşif, seri detayı ve kesintisiz okuyucu akışı responsive olarak tamamlandı. Hesap, kütüphane ve ilerleme D1'e bağlandı."] },
    { title: "02 · Görsel yön", paragraphs: ["Gece Vardiyası için özgün bir style master üretildi. Panel üretimine geçmeden önce karakter, ışık, renk ve kadraj tutarlılığı kontrol ediliyor."] },
    { title: "03 · Yayın hattı", paragraphs: ["Sıradaki adım Studio üzerinden seri, bölüm ve panel yükleme; taslak önizleme ve yayınlama akışını D1 + R2 ile tamamlamak."] },
    { title: "04 · Gelir deneyi", paragraphs: ["Ana sayfa ve seri detayındaki reklam yerleri Google'ın resmî test ağıyla localhost üzerinde doğrulanıyor; gerçek publisher veya gelir hesabı kullanılmıyor."] },
  ]} />;
}
