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
