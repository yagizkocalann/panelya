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

Repository private ve mevcut GitHub planı zorunlu branch protection/ruleset desteklemediği sürece yeşil `Web quality` sonucu merge için manuel ama zorunlu ekip kuralıdır. Plan desteği geldiğinde aynı check `main` için required status check yapılır; workflow adı değiştirilmez.

Flutter uygulaması `main`e alınana kadar web workflow'u mobil SDK kurmaz. `apps/mobile` implementasyonunu taşıyan PR, kendi ayrı mobil kalite işini de birlikte getirir: sabitlenmiş Flutter sürümü, `flutter pub get`, `flutter analyze` ve `flutter test`. Mobil ekip web workflow dosyasını paralel branch'te değiştirmez; ortak CI değişiklikleri küçük PR ile `main` üzerinden paylaşılır.
