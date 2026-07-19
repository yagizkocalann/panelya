# Web gelistirme devir rehberi

Bu dosya Panelya web ve Studio gelistirmesine baska bir bilgisayarda, yeni bir
Codex gorevinde devam etmek icin operasyonel baslangic noktasidir. Mimari kararlarin
tek kaynagi degildir; celiski halinde `AGENTS.md`, `production-bible.md` ve ilgili ADR
once gelir.

## Zorunlu okuma sirasi

Yeni Codex, kod degistirmeden once su dosyalari tamamen okur:

1. `AGENTS.md`
2. `production-bible.md`
3. `docs/web-development-handoff.md` (bu dosya)
4. Yapacagi isle ilgili runbook veya karar dosyasi
5. Kullanici tarafindan denenecek bir akis varsa `docs/manual-qa-checklist.md`

Ortak web/mobil sozlesmesi degisecekse ayrica `docs/mobile-handoff.md` ve
`packages/contracts/README.md` okunur. `.env` degerleri hicbir araca, dokumana,
mesaja veya loga kopyalanmaz.

## Repository ve sahiplik

- Repository: `https://github.com/yagizkocalann/panelya`
- Dogrulanmis ortak kaynak: `origin/main`
- Web ve Studio: kok Next.js/vinext uygulamasi; Codex sorumlulugunda.
- Mobil: `apps/mobile`; Claude'un `codex/mobile` branch'indeki sorumlulugunda.
- Ortak API: `packages/contracts/schema.json`, HTTP eslemesi
  `packages/contracts/openapi.json`, sentetik ornekler
  `packages/contracts/fixtures`.
- Web branch'i mobil uygulama dosyalarini degistirmez. Mobil branch de web/shared
  degisikliklerini dogrudan uretmez; ortak degisiklikler kucuk PR ile `main`e girer.

Mobil uygulama henuz `main`de olmayabilir. Bu durumda kok clone icinde `apps/mobile`
gorulmemesi kayip veri degildir; guncel mobil kod `origin/codex/mobile` uzerindedir.
Claude mobil PR'ini hazirlayana kadar web Codex'i bu branch'i main'e tasimaya veya
yeniden duzenlemeye calismaz.

## Ayni bilgisayarda Claude ve Codex

Claude mobil, Codex web tarafinda ayni anda calisacaksa ayni working tree'yi
paylasmazlar. Bir ajanin `git switch`, build veya format islemi digerinin acik
dosyalarini ve branch'ini degistirebilir. Mobil mevcut clone'da kalir; web icin ayri
bir Git worktree veya ikinci clone kullanilir.

Mobil klasorunde Claude once kendi calisma agacini koruyarak guncellenir:

```bash
git status --short --branch
git fetch origin --prune
git switch codex/mobile
git merge origin/main
git push origin codex/mobile
```

Ayni repository'den kardes web worktree'si olusturmak icin mobil klasorunun ust
dizininde benzersiz bir is adi secilir:

```bash
git fetch origin --prune
git worktree add ../panelya-web -b codex/web-<kisa-is-adi> origin/main
cd ../panelya-web
npm ci
npm test
```

Claude yalniz mobil worktree'de, Codex yalniz web worktree'de calisir. Iki ajan ayni
branch'i ayni anda checkout etmez; ortak contracts degisikligi yine ayri PR ile
`main` uzerinden paylasilir. Worktree olusturmadan once hedef klasorun ve branch
adinin bosta oldugu kontrol edilir; var olan klasor silinmez veya uzerine yazilmaz.

## Yeni bilgisayarda guvenli baslangic

Temiz clone icin:

```bash
git clone https://github.com/yagizkocalann/panelya.git
cd panelya
git fetch origin --prune
git switch main
git pull --ff-only origin main
npm ci
npm test
```

Mevcut clone icin once calisma agacini kontrol et. Kullaniciya ait degisiklikleri
silme, resetleme veya uzerine yazma:

```bash
git status --short --branch
git fetch origin --prune
git switch main
git pull --ff-only origin main
npm ci
npm test
```

Yeni web isi `origin/main` tabanli, amacini anlatan ayri bir branch'te baslar:

```bash
git switch -c codex/web-<kisa-is-adi> origin/main
```

Uzun omurlu `codex/web` branch'ini yeni isler icin temel alma. Her teslim kucuk bir
PR olur; zorunlu `Web quality` ve ilgiliyse `Mobile quality` kontrolleri gecmeden
merge edilmez.

## Runtime kurulumu

- Node surumu `.nvmrc` ile `22.13.0`; `package.json` en az `22.13.0` ister.
- Paket yoneticisi npm; temiz kurulumda `npm ci` kullan.
- Yerel ortam gerekiyorsa `.env.example` dosyasini `.env` olarak kopyala ve degeri
  yalniz yeni bilgisayarda doldur. `.env` Git'e girmez.
- Sunucu `npm run dev` ile acilir. Terminalin yazdigi origin esas alinir; varsayilan
  bos portta public site genellikle `http://localhost:3000`, Studio ise
  `http://studio.localhost:3000` olur.
- Studio ve public host ayni D1/R2 emulasyonunu kullanir ama host-only oturumlari
  ayri oldugu icin ikisine ayri giris gerekir.

Temel kalite komutlari:

```bash
npm run lint
npm test
npm run test:contracts
```

`npm test` build ile rendered HTML, contracts ve recovery bundle testlerini birlikte
calistirir. Degisen UI ayrica 1440, 1024, 768, 390 ve 360 px genisliklerde; klavye,
focus, en az 44 px dokunma hedefi, console ve bozuk link acisindan tarayicida denenir.

## Git ile tasinmayan yerel durum

Kod ve sentetik fixture'lar Git ile gelir; bu bilgisayardaki yerel D1/R2 durumu
gelmez. `.wrangler/`, `.env`, loglar, yerel yedekler ve agir gorsel uretim ciktilari
bilerek ignore edilir.

Bunun sonucu olarak yeni bilgisayarda:

- Ilk localhost kaydi yeniden `admin` olur. Bu yalniz yerel QA kuralidir; sabit bir
  admin e-postasi veya sifresi repoda yoktur. Test hesabi ve parolasi yeniden secilir.
- Public oturum ve Studio oturumu ayri ayri acilir.
- Onceki bilgisayarda Studio'ya yuklenen R2 medyasi, outbox kayitlari, davet tokenlari,
  yorumlar ve diger D1 mutation'lari tasinmaz.
- Typed seed bos yerel veritabanini uygulamanin acilisinda tekrar kurar. Ozellikle
  cok hesapli veya yuklemeli bir QA senaryosu icin gerekli sentetik veri yeni
  bilgisayarda yeniden olusturulur.
- Gercek yerel veriyi tasimak gerekirse `.wrangler` klasoru Git'e eklenmez. Bunun
  yerine `docs/backup-restore-runbook.md` izlenir ve hassas export commit edilmez.

## Mimari harita

- `app/`: public ve Studio App Router sayfalari, route handler'lar ve UI.
- `app/data`: katalog/domain verisinin tek kaynagi ve typed seed.
- `app/lib`: auth, D1/R2, servis adapter'lari ve ortak sunucu kurallari.
- `app/studio`: kaynak route'lari; dis URL'ler Studio hostunda `/`, `/content`,
  `/media`, `/messages`, `/ads`, `/outbox`, `/moderation`, `/users`, `/audit`, `/qa`.
- `db/` ve `drizzle/`: D1 semasi, sorgular ve migration'lar.
- `worker/`: Cloudflare runtime/consumer siniri.
- `packages/contracts`: web ve Flutter arasindaki dil bagimsiz contract kaynagi.
- `tests/`: build sonrasi HTML, contract ve recovery dogrulamalari.
- `docs/`: ADR'lar, runbook'lar ve manuel QA kuyrugu.
- `public/images`: yalniz runtime'in kullandigi optimize WebP dosyalari.
- `artifacts/`: kural kitabi, manifest ve arastirma metni kalabilir; agir raster
  uretimler Git'e girmez.

Public veya Studio'da tiklanabilir gorunen her kontrol gercek route, mutation ya da
etkilesime bagli olmak zorundadir. Placeholder buton birakilmaz.

## Tamamlanan urun yuzeyi

Web tarafinda su temel alanlar calisir ve test kapsamina sahiptir:

- Responsive kesif, katalog arama/filtre/siralama/cursor, seri detayi ve dikey
  okuyucu.
- Uzun okuyucuda panel lazy load, oranla CLS korumasi, eksik gorsel geri donusu ve
  cihazda devam konumu.
- Yerel kayit/giris/cikis, e-posta dogrulama, sifre sifirlama, profil, parola,
  oturumlar ve hesap silme.
- Kutuphane, favori, seri takibi, yeni bolum tercihi ve yerel bildirim outbox'i.
- Puan, yorum, spoiler, rapor, tek seviyeli yanit, begeni, kullanici engelleme ve
  Studio moderasyonu.
- Kurumsal/yasal sayfalar, iletisim formu, telif bildirimi ve gizli durum takibi.
- SEO canonical/robots/sitemap/ComicSeries JSON-LD ve genis responsive footer.
- Google'in yalniz resmi test reklam birimiyle yerel reklam QA'si; gercek publisher
  kimligi veya tiklama otomasyonu yoktur.
- Ayri Studio hostu; seri/bolum CRUD, taslak/yayin/arsiv, yayin oncesi kontrol,
  toplu panel islemleri, R2 medya, responsive turetme, guvenli taslak onizleme,
  mesajlar, kullanicilar/roller, admin daveti, audit, outbox ve readiness ekrani.

En ayrintili mevcut durum `production-bible.md`; kullaniciya sonradan hatirlatilacak
testler `docs/manual-qa-checklist.md` icindedir. Bu rehber o iki dosyanin yerine gecmez.

## Mobil icin merge edilmis ortak teslimler

1. Responsive medya contract'i PR #20 ile `main`e girdi. OpenAPI `1.1.0`; response
   `schemaVersion` geriye uyumlu `1.0`; `PublicMediaVariant` ve opsiyonel kapak/panel
   varyantlari ortak fixture'larda bulunur.
2. Production auth/session contract'i PR #21 ile `main`e girdi. OpenAPI `1.2.0`;
   Auth0, sistem tarayicili Authorization Code + PKCE, access/refresh/revoke/me
   sekilleri ve sentetik auth fixture'lari hazirdir.

Bu contract'lar gercek servislerin kuruldugu anlamina gelmez. Mobil codegen ve adapter
calismasi baslayabilir; gercek Auth0 login smoke testi tenant/runtime entegrasyonunu
bekler.

## Siradaki web isleri

Engel durumuna gore su sirayi koru:

1. Auth0 tenant/custom domain degerleri saglandiginda production token gateway,
   JWKS dogrulama, provider identity D1 migration'i, web callback'i ve hesap baglama
   akisini uygula. Mevcut `/api/auth/config`, `/api/auth/mobile/token` ve
   `/api/auth/mobile/revoke` gercek entegrasyon yokken fail-closed kalir.
2. Deployment ortaminda Cloudflare Queue producer/consumer, Images, Rate Limiting
   namespace ve DLQ kaynaklarini provision et; `docs/platform-deployment-readiness.md`
   ve `QA-OPS-01` ile smoke test yap.
3. Canli e-posta saglayicisini mevcut vendor-bagimsiz notification adapter'ina bagla;
   yerel D1 outbox davranisini bozma.
4. Analitik, hata izleme, performans butcesi, consent/CMP ve reklam test/canli ortam
   ayrimini tamamla.
5. Production yedek kovasi, retention lock, zamanlanmis export-copy, recovery tatbikati
   ve gercek domain SEO smoke testlerini tamamla.
6. Karsi bildirim, resmi tebligat, saklama/SLA ve diger yasal metinleri hukuk
   incelemesiyle kesinlestir.

Bir is gercek hesap, domain, secret, platform kaynagi veya hukuk karari gerektiriyorsa
tahminle deger uydurma. Yerel adapter, fixture, fail-closed davranis ve testleri
hazirlayabilirsin; dis bagimliligi acikca raporla ve sonraki bloklanmamis ise gec.

## Icerik ve gelir siniri

OkuToon benzeri kesif, kategori, footer, ucretsiz okuma ve reklam/Premium urun fikri
referans alinabilir; referans sitenin logo, marka, metin, kod veya telifli bolum
gorselleri kopyalanmaz. Katalog yalniz ozgun, komisyonlu, lisansli veya kaynagi ve
kullanim hakki acikca dogrulanmis icerik kullanir. "Baska sitelerde de var" ifadesi
yayin hakki kaniti sayilmaz. Ucretli bolum/abonelik ancak lisans ve odeme modeli
kesinlestikten sonra uygulanir.

GPT Image ile yeni bolum uretme isi kullanici karariyla simdilik durdurulmustur.
Mevcut kural kitabi ve manifestler korunur; yeni gorsel uretme veya agir dosya
commit'i sonraki web gorevinin varsayilan parcasi degildir.

## Bir gorevin teslim kontrolu

1. Acceptance criteria tamamlandi.
2. `git diff` yalniz amaclanan dosyalari iceriyor.
3. `npm run lint` ve `npm test` basarili.
4. Degisen UI gerekli viewport ve etkilesim turlerinden gecti; console/link hatasi yok.
5. Mimari/urun davranisi degistiyse `production-bible.md` guncellendi.
6. Kullanici tarafindan tekrar denenecek akis URL, on kosul ve beklenen sonucuyla
   `docs/manual-qa-checklist.md` dosyasina eklendi.
7. Branch push edildi, PR acildi, Web/Mobile kalite kontrolleri gecti ve PR main'e
   merge edildi.
8. Merge sonrasi yerel `main`, `origin/main` ile fast-forward senkronlandi.

## Yeni Codex'e verilecek baslangic talimati

Asagidaki metin yeni Codex gorevine oldugu gibi verilebilir:

> `yagizkocalann/panelya` reposunda web ve Studio tarafina devam et. Once
> `AGENTS.md`, `production-bible.md` ve `docs/web-development-handoff.md` dosyalarini
> tamamen oku. Calisma agacini koruyarak `origin/main`i guncelle ve yeni isi
> `origin/main` tabanli `codex/web-<is>` branch'inde yap. `apps/mobile` ve
> `codex/mobile` Claude'un alanidir; mobil dosyalarina dokunma. Handoff rehberindeki
> siradaki bloklanmamis web isini sec, ilgili runbook/ADR'yi oku, uygula, lint/test/build
> ve gereken manuel responsive QA'yi tamamla; dokuman ve QA kaydini guncelleyip PR
> ac. Telifli referans icerik kopyalama ve `.env` degeri yazdirma.
