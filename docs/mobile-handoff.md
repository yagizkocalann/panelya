# Mobil uygulama devralma notu

## Başlangıç ilkesi

Mobil uygulama mevcut web arayüzünü React Native'e taşımaya çalışmaz. Expo Router ayrı bir istemci olur; web uygulamasının API sözleşmelerini, domain kurallarını ve daha sonra ayrıştırılacak TypeScript tiplerini kullanır.

Mobil geliştirme `codex/mobile` branch'inde ve `apps/mobile` dizininde başlar. Web uygulamasını `apps/web` altına taşıyan monorepo refactor'u mobil başlangıcının ön koşulu değildir; bu değişiklik iki branch arasında gereksiz çatışma yaratmamak için ayrıca planlanır.

## İlk mobil kapsam

1. Keşif ve katalog
2. Seri detay ve bölüm listesi
3. Dikey okuyucu
4. API hata/boş/yükleniyor durumları
5. Deep-link taslağı

Hesap, kütüphane, çevrimdışı okuma ve bildirimler; API kimlik modeli ve mobil oturum stratejisi kesinleştikten sonra eklenir.

## Mevcut API başlangıç noktaları

- `GET /api/catalog`
- `GET /api/series/:slug`
- `GET /api/series/:slug/episodes/:episodeSlug`
- `POST /api/auth/*`
- `GET/POST /api/library/*`
- `POST /api/progress`

Mobil istemci D1 veya R2'ye doğrudan bağlanmaz. Bütün veri erişimi web deployment'ındaki API sınırından geçer.

## Kimlik doğrulama uyarısı

Mevcut yerel auth akışı HttpOnly web cookie'sine dayanır ve production kimlik sağlayıcısı değildir. Mobil branch bu cookie davranışını kalıcı sözleşme kabul etmemelidir. İlk mobil dikey dilimde public katalog/okuyucu önceliklidir; production auth adaptörü daha sonra web ve mobil için ortak bir sözleşmeyle seçilir.

## Yerel cihaz testi

Simulator aynı Mac üzerinde çalışan web API'sine erişebilir. Fiziksel cihazda `localhost` Mac'i değil telefonu ifade eder; API origin'i Mac'in yerel ağ adresine veya güvenli bir geliştirme tüneline ayarlanmalıdır. Origin değeri kaynak koda gömülmez, mobil environment/config katmanından okunur.

## Ortak değişiklik sınırı

Aşağıdakiler `main` üzerinden koordine edilir:

- API alan adı veya JSON şekli değişiklikleri
- auth/session sözleşmesi
- seri, bölüm, panel ve okuma ilerlemesi tipleri
- medya URL ve cache davranışı
- D1 migration'ları

Yalnız mobil navigasyon, native UI, cihaz depolaması ve Expo yapılandırması `codex/mobile` içinde bağımsız ilerleyebilir.
