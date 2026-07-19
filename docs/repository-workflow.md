# Repository ve branch çalışma düzeni

## Branch sahipliği

- `main`: Web ve mobilin ortak, doğrulanmış başlangıç noktasıdır. Doğrudan günlük geliştirme yapılmaz.
- `codex/web`: Windows tarafındaki aktif web geliştirme branch'idir.
- `codex/mobile`: MacBook tarafındaki Flutter/mobil geliştirme branch'idir (ADR-019). MacBook'ta güncel `origin/main` üzerinden oluşturulur.

Uzun süreli iki branch aynı dosyaları gereksiz yere değiştirmemelidir. Web'e özgü değişiklikler mevcut kök uygulamada; mobil uygulama kodu ileride `apps/mobile` altında tutulur. Ortak API sözleşmesi veya domain tipi gerektiğinde önce küçük ve bağımsız bir değişiklik olarak `main` üzerinde uzlaştırılır.

## İlk GitHub yayını

1. Kalite kapıları `main` üzerinde çalıştırılır.
2. Temiz başlangıç commit'i `main` olarak GitHub'a gönderilir.
3. Windows'ta `codex/web`, `origin/main` üzerinden oluşturulur ve web geliştirmesi burada sürer.
4. MacBook'ta repository clone edildikten sonra `codex/mobile`, `origin/main` üzerinden oluşturulur.

## MacBook başlangıcı

```bash
git clone <GITHUB_REPO_URL>
cd webtoon
git switch -c codex/mobile origin/main
npm ci
npm test
```

Mobil branch ilk aşamada web kökünü taşımamalıdır. Flutter uygulaması `apps/mobile` altında yaşar; API/domain ortaklaştırması gerçek ihtiyaç çıktıkça dil bağımsız `packages/contracts` (JSON Schema/OpenAPI) ve `packages/domain` sınırlarına taşınır.

## Güncel kalma

Her iki çalışma hattı düzenli olarak doğrulanmış `main` değişikliklerini alır:

```bash
git fetch origin
git merge origin/main
```

Çapraz branch merge yerine küçük pull request'lerle `main` üzerinden paylaşım tercih edilir. Veritabanı şeması, API cevap biçimi, auth sözleşmesi ve katalog modeli iki istemciyi de etkilediği için ortak değişiklik sayılır.

## Commit edilmeyen dosyalar

- `.env*` dosyaları (`.env.example` hariç)
- `.wrangler`, yerel D1/R2 emülasyon verileri ve loglar
- `artifacts/` altındaki üretilmiş PNG/JPEG/WebP araştırma çıktıları
- `public/images` altındaki büyük PNG/JPEG kaynaklar
- build, coverage ve dependency çıktıları

Prompt, provenance, manifest, QA ve kural kitabı gibi metin dosyaları Git'te kalır. Web'in kullandığı raster dosyalar optimize edilmiş WebP olarak commit edilir.

## Görsel optimizasyonu

Yeni bir public PNG/JPEG kaynak eklendiğinde WebP kardeşi şu komutla oluşturulur:

```bash
python scripts/optimize_public_images.py --quality 84 --force
```

Uygulama yalnız `.webp` yoluna bağlanır. Büyük kaynak görsel yerelde veya daha sonra kararlaştırılacak harici obje depolamasında tutulur; Git geçmişine eklenmez.

## Kalite kapıları

Her merge öncesi:

```bash
npm test
npm run lint
npm run build
```

GitHub Actions `Quality / Web quality` işi, `main` hedefli pull request'lerde ve `main`/`codex/web` push'larında `.nvmrc` içindeki Node sürümüyle `npm ci`, lint, build ve test zincirini çalıştırır. `npm test` build adımını zaten kapsadığı için workflow bunu ikinci kez çalıştırmaz. Eski commit için devam eden iş, aynı PR'a yeni commit geldiğinde iptal edilir.

Temiz clone build'inin yerelle aynı davranması için `.openai/hosting.json` repoda tutulur; dosya yalnız `DB` ve `MEDIA` mantıksal binding adlarını taşır. Ortam değerleri ve secret'lar bu dosyaya yazılmaz; `.env*` veya hosted runtime ayarlarında kalır.

Public repository'de `main` branch protection, `Web quality` ve `Mobile quality` kontrollerini required status check olarak zorunlu kılar. Pull request ve güncel branch olmadan main'e merge yapılmaz; force-push ve branch silme kapalıdır.

`Mobile quality` işi her PR'da görünür fakat yalnız `apps/mobile`, `packages/contracts` veya kalite workflow'u değiştiğinde ve mobil uygulama ref içinde mevcutsa Flutter SDK kurar. Mobil branch'teki `.metadata` revision'ıyla eşleşen Flutter `3.44.6 stable` kullanılır; kilitli `pub get`, `flutter analyze` ve `flutter test` otomatik çalışır. Bu nedenle mobil ekibin ayrıca workflow yazması veya hatırlatma beklemesi gerekmez. Flutter sürüm yükseltmesi mobil metadata ve CI pin'ini aynı PR'da değiştirir.
