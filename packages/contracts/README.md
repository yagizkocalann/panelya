# Panelya ortak API sözleşmeleri

Bu dizin web ve Flutter istemcilerinin paylaştığı dil bağımsız public API sözleşmesinin tek kaynağıdır.

- `schema.json`: JSON Schema 2020-12 ile veri şekilleri.
- `openapi.json`: Public endpoint ve HTTP response eşlemesi.
- `fixtures/`: Telifsiz, sentetik ve her istemcinin parser testlerinde kullanabileceği örnek cevaplar.

## Değişiklik kuralı

1. Mevcut zorunlu alanı kaldırmak, tipini değiştirmek veya enum değerini daraltmak breaking değişikliktir; yeni bir `schemaVersion` ve koordineli istemci geçişi gerektirir.
2. Opsiyonel alan eklemek geriye uyumlu olabilir; yine de web drift testi ve Flutter parser testi birlikte güncellenir.
3. Route handler cevabı değişmeden önce bu kaynak ve fixture'lar güncellenir.
4. Sözleşme değişikliği küçük bir ortak PR ile `main` üzerinden iki istemciye dağıtılır.

## Yerel doğrulama

```bash
npm run test:contracts
```

Test, fixture'ları ve derlenmiş Worker'ın gerçek katalog/seri/okuyucu cevaplarını aynı JSON Schema tanımlarına karşı doğrular.

V1'de `updatedAt`, `publishedAt` ve `followers` alanları mevcut API davranışını koruyan yerelleştirilmiş gösterim metinleridir. Makine-dostu tarih ve sayısal takipçi alanlarına geçiş ayrı, sürümlü bir sözleşme değişikliği olarak ele alınacaktır.

`coverImageVariants` ve panel görselindeki `variants` alanları opsiyonel ve geriye uyumludur. Yalnız üretimi tamamlanmış public WebP türevleri, artan genişlik sırasıyla URL/boyut/MIME bilgisi taşır. İstemci uygun varyant yoksa mevcut `coverImage` veya `image.src` kaynağına düşer; R2 storage key'i, Studio metadata'sı ya da Queue işi istemciye açılmaz.

Production auth sözleşmesi ADR-039 uyarınca Auth0, Authorization Code + PKCE, 15 dakikalık Bearer access tokeni ve dönen refresh tokeni modelini tanımlar. `auth-*.v1.json` fixture'ları `.example`/`.test` alan adları ve açıkça geçersiz sentetik tokenlar kullanır. Bunlar runtime yapılandırması veya geliştirici kimlik bilgisi değildir. Web host-only cookie kullanabilir; Flutter bu cookie'yi taklit etmez ve tokenları yalnız OS secure storage'da saklar.

Editorial keşif sözleşmesi ADR-044 uyarınca `GET /api/discovery` üzerinden öne çıkan seri/ilk bölüm, türler, en fazla 100 yeni seri ve gerçek yayın sırasındaki en fazla 100 bölüm güncellemesini taşır. `publishedAt` gösterim metnidir; istemci sıralamayı yeniden hesaplamaz ve API sırasını korur. Discovery cevapları panel gövdeleri veya dahili timestamp/storage/Queue metadata'sı taşımaz.

Production hesap sözleşmesi ADR-047 uyarınca web host-only session cookie'si
ve Flutter Bearer tokenini aynı `/api/account/*` yüzeyinde kabul eder.
`AccountOverviewResponse` sağlayıcı türü yanında ekran kararlarını sunucudan
gelen capability alanlarıyla taşır; istemci provider davranışını tahmin etmez.
Aktif oturumlar credential veya IP adresi açmaz, silme etkileri
yerelleştirilmiş cümleler yerine yapılandırılmış kodlardır.

Taze doğrulama iki aşamalıdır:
`/api/account/reauthentication/start`, `S256` challenge ve amaca göre
`max_age=0` sistem tarayıcısı URL'si üretir; `complete`, authorization code'u
request/state/PKCE/redirect/nonce/`auth_time` bağlamında doğruladıktan sonra
en fazla 10 dakikalık, amaca bağlı ve tek kullanımlık Panelya
`reauthenticationToken` döndürür. Ham authorization code hassas mutation'a
verilmez ve bu akış mevcut mobil login tokenlarını değiştirmez.

`account-*.v1.json` fixture'ları yalnız sentetik `.example`/`.test`
değerleridir. Gerçek Auth0 domaini, kullanıcı parolası, access/refresh token,
client secret veya Management API credential'ı değildir.

Kütüphane ve favori sözleşmesi ADR-048 uyarınca web session cookie'si ile mobil
Bearer tokenini aynı `GET /api/library` ve `POST/DELETE
/api/library/{slug}` yüzeyinde kabul eder. Bearer okumada `read:library`, yazmada
`write:library` scope'u ister. JSON `POST`, yarışa açık toggle yerine hedef
`status` ve `favorite` değerlerini birlikte taşır. Cevaplar yalnız public seri
kartı metadata'sı ve `episodeCount` içerir; panel, storage, Queue veya Studio
metadata'sı taşımaz. `library-*.v1.json` dosyaları tamamen sentetik parser
fixture'larıdır.

Okuma ilerlemesi sözleşmesi ADR-049 uyarınca web session cookie'si ile mobil
Bearer tokenini aynı `GET/POST /api/progress` yüzeyinde kabul eder. Mevcut Auth0
izin setini bozmamak için Bearer okuma ve yazma işlemleri v1'de birlikte
`write:progress` scope'unu ister. `POST`, istemcinin hedef `seriesSlug`,
`episodeSlug` ve tam sayı `percent` değerini birlikte taşır; sunucu bölüm başlığı,
sırası ve public kart metadata'sını yayınlanmış katalogdan türetir. `GET`, seri
başına son kaydı sunucu zamanına göre sıralar. Yüzde `100`, ilgili bölümün
tamamlandığını belirtir; istemci sonraki bölümü seri detayındaki yayın sırasından
bulur. Anonim web okuyucusunda ilerleme cihazda kalır ve `POST` geriye uyumlu
olarak `204` döner. `reading-progress-*.v1.json` fixture'ları sentetiktir.
