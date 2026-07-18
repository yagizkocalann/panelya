# Mobil uygulama devralma notu

## Başlangıç ilkesi

Mobil uygulama mevcut web arayüzünü taşımaya çalışmaz. Flutter ayrı bir istemci olur (ADR-019); web uygulamasının API sözleşmelerini ve domain kurallarını kullanır. Dart modelleri `schemaVersion` taşıyan JSON sözleşmesinden türetilir; TypeScript kod paylaşımı hedeflenmez.

İskelet, Novel-Project uygulamasının kanıtlanmış kalıplarından devralınır: feature-first dizin yapısı, Riverpod state yönetimi, go_router (deep-link hazır), design token teması ve `env/` dart-define katmanı. Novel'in Firebase veri katmanı taşınmaz; aynı repository interface deseninin arkasına Panelya REST client'ı yazılır. Episode player'ı (dikey video pager) kullanılmaz; webtoon okuyucusu kesintisiz dikey panel scroll'u olarak sıfırdan uygulanır.

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

## Paralel çalışma düzeni

- Mobil geliştirme yalnız `codex/mobile` branch'inde, `apps/mobile` altında ilerler; branch `origin/main` tabanlıdır.
- Web tarafındaki `codex/web` veya `codex/studio-media-workflow` branch'leri doğrudan merge edilmez; ortak değişiklikler `main` üzerinden alınır.
- Root web uygulaması `apps/web` altına taşınmaz; monorepo refactor'u ayrı planlanır.
- Her commit öncesi değişikliğin mobil kapsamla sınırlı olduğu kontrol edilir. Web/shared dosyada değişiklik gerektiği fark edilirse doğrudan değiştirilmez; hangi ortak sözleşmenin gerektiği raporlanır ve `main` üzerinden koordine edilir.

## Ortaklık kuralları

1. Web bileşenleri kopyalanmaz; platforma özgü Flutter widget'ları yazılır ama ortak tasarım token'ları kullanılır.
2. Seri, bölüm, panel, medya, okuma ilerlemesi, pagination ve API hata modellerinin bağımsız mobil kopyaları türetilmez; Dart modelleri API JSON sözleşmesini birebir izler.
3. Ortak sözleşmeler ileride `packages/contracts` altında toplanacak. Bu paket `main`'e gelene kadar mobil tarafta kalıcı alternatif paket açılmaz; `apps/mobile/lib/core/contracts/` altında TEK bir adapter katmanı tutulur ve dosya başlıklarında açıkça GEÇİCİ olarak işaretlenir. `codex/studio-media-workflow` çıktıları `main`'e gelince bu adapter ortak sözleşmeyle değiştirilir.
4. Tasarım değerleri ileride `packages/design-tokens` tek kaynağına bağlanacak; o zamana kadar mobil tema `app/globals.css` token'larını birebir aynalar (aşağıdaki tablo).
5. API çağrıları ekran widget'larına dağıtılmaz; `apps/mobile/lib/core/api/` altındaki merkezi client katmanından geçer.
6. API origin'i kaynak koda gömülmez; `env/` dart-define config katmanından okunur.

## Tasarım token'ları (kaynak: `app/globals.css`)

| Token | Değer | Kullanım |
| --- | --- | --- |
| background | `#07100e` | Ana arka plan (koyu orman yeşili) |
| surface | `#0b1512` | Ana yüzey |
| surface2 | `#101d19` | İkinci yüzey |
| surface3 | `#162520` | Üçüncü yüzey |
| ink | `#f3f6f2` | Ana metin |
| muted | `#94a39d` | Soluk metin |
| line | `rgba(197,226,213,.14)` | Çizgi/kenarlık |
| mint | `#66e2ae` | Ana vurgu |
| mintStrong | `#35c98e` | Güçlü vurgu |
| coral | `#ff6f61` | Uyarı/ikincil vurgu |

Yeni veya bağımsız renk paleti oluşturulmaz. Mobil birebir web kopyası olmaz; ancak tipografi hiyerarşisi, içerik sırası, kart dili, renkler ve durum mesajları aynı ürün ailesinden görünür.

## Kalite çizgisi

- Dokunma hedefleri en az 44x44.
- Safe area, native geri hareketi ve erişilebilirlik (semantics, dinamik yazı boyutu, azaltılmış hareket) desteklenir.
- Her ekran loading, empty, error (retry ile) ve success durumlarını tamamlar.
- Görünür olup çalışmayan buton veya placeholder bırakılmaz (ADR-010 mobilde de geçerli).

## Şimdilik sonraya bırakılanlar

Production auth, favori/kütüphane hesabı, push bildirimleri, çevrimdışı indirme, abonelik/ödeme ve Studio/admin ekranları ilk mobil kapsamın dışındadır.

## Ortak değişiklik sınırı

Aşağıdakiler `main` üzerinden koordine edilir:

- API alan adı veya JSON şekli değişiklikleri
- auth/session sözleşmesi
- seri, bölüm, panel ve okuma ilerlemesi tipleri
- medya URL ve cache davranışı
- D1 migration'ları

Yalnız mobil navigasyon, native UI, cihaz depolaması ve Expo yapılandırması `codex/mobile` içinde bağımsız ilerleyebilir.
