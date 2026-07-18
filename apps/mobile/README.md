# panelya_mobile

Panelya'nın Flutter mobil istemcisi (Faz 1 iskeleti). Web uygulamasının
`/api/*` sınırını kullanan ayrı bir istemcidir (ADR-019); web UI kodu
taşınmaz. Ayrıntılar için repo kökündeki `production-bible.md` (özellikle
ADR-019) ve `docs/mobile-handoff.md`'ye bakın.

## Kapsam (Faz 1)

- Keşif/katalog listesi (`GET /api/catalog`)
- Seri detay ve bölüm listesi (`GET /api/series/:slug`)
- Dikey okuyucu (`GET /api/series/:slug/episodes/:episodeSlug`)
- Yükleniyor/boş/hata (tekrar dene ile)/başarı durumları
- Deep-link hazır rotalar: `/`, `/series/:slug`, `/series/:slug/read/:episodeSlug`

Auth, favori/kütüphane, push, çevrimdışı, ödeme ve Studio ekranları bu
fazın kapsamı dışındadır.

## Ortam yapılandırması (API origin)

API origin'i kaynak koda gömülmez; derleme zamanında
`--dart-define-from-file` ile enjekte edilir. `env/local.json`:

```json
{
  "API_ORIGIN": "http://localhost:3000"
}
```

Çalıştırma:

```sh
flutter run --dart-define-from-file=env/local.json
```

Bir define verilmezse `API_ORIGIN` varsayılan olarak
`http://localhost:3000`'e düşer (bkz. `lib/core/config/app_config.dart`).

### Fiziksel cihazda test etme

Simulator/emulator aynı Mac'te çalışan web API'sine `localhost` üzerinden
erişebilir. **Fiziksel bir cihazda `localhost` telefonun kendisini işaret
eder, Mac'i değil.** Fiziksel cihaz testinde `env/local.json` içindeki
`API_ORIGIN` değerini Mac'in yerel ağ adresine ayarlayın, örn.:

```json
{
  "API_ORIGIN": "http://192.168.1.23:3000"
}
```

Mac'in yerel ağ adresini `ipconfig getifaddr en0` (Wi-Fi) ile bulabilirsiniz.
Telefon ve Mac aynı yerel ağda olmalı ve web geliştirme sunucusu
(`npm run dev`, repo kökünde) çalışıyor olmalıdır.

## Geliştirme

```sh
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=env/local.json
```

## Mimari notlar

- **Tema**: `lib/app/theme/` — tüm renk/spacing/tipografi token'ları
  `docs/mobile-handoff.md`'deki tabloyla birebir eşleşir. Koyu tema tek
  temadır. Ekranlar token dışında değer hardcode etmez.
- **Sözleşmeler**: `lib/core/contracts/` — `packages/contracts` `main`'e
  gelene kadar geçici tek adapter katmanı (her dosyanın başında bu not
  bulunur). Web tarafının `app/api/catalog`, `app/api/series/[slug]` ve
  `app/api/series/[slug]/episodes/[episode]` route handler'larının
  döndürdüğü gerçek JSON şeklini birebir aynalar.
- **API client**: `lib/core/api/` — tek merkezi HTTP client; network/4xx/5xx
  /parse hata ayrımı ve `schemaVersion` uyumsuzluğunda açık hata fırlatır.
  Ekranlar bu client'ı doğrudan değil, her feature'ın repository interface'i
  (Riverpod provider'ı) üzerinden kullanır.
- **Router**: `lib/app/router/` — go_router, deep-link hazır üç rota.
- **Feature-first yapı**: `lib/features/<feature>/{domain,data,presentation}`
  (Novel-Project'ten devralınan kalıp; Firebase/video player/AdMob/RevenueCat
  kodu kopyalanmadı).
