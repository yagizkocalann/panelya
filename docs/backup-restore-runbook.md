# Panelya D1 ve R2 yedekleme / geri yukleme runbook'u

Bu runbook production verisi icindir. Yerel QA, sentetik paketle yapilir. Gercek SQL exportu kullanici, oturum ve operasyon verisi icerebilir; Git'e, issue'ya, log'a veya ekran goruntusune eklenmez. `.backups/` ve `recovery-bundles/` Git tarafindan dislanir.

## Hedef ve katmanlar

| Katman | Amac | Gecici hedef |
| --- | --- | --- |
| D1 Time Travel | Son hatali mutation veya migration'dan dakika bazli geri donus | RPO <= 1 dakika; Cloudflare planina gore 7 veya 30 gun pencere |
| D1 tam SQL exportu | Time Travel penceresi disi ve tasinabilir kurtarma | Gunluk; RPO <= 24 saat; 90 gun saklama |
| R2 immutable yedek kovasi | Canli kovada nesne/bucket kaybina karsi ikinci kopya | Yeni hashli nesneleri en gec 24 saatte kopyala; gunluk manifesti 90 gun sakla |
| Sentetik kurtarma tatbikati | Prosedur ve artifact biciminin calistigini kanitlama | Her ay ve schema/storage degisikliginden sonra |

Bu hedefler canli trafik, maliyet ve mevzuat envanteri tamamlandiginda yeniden onaylanir. D1 Time Travel production backend'de otomatik aciktir; Workers Free icin 7, Paid icin 30 gun tutulur. Tek basina uzun sureli yedek degildir.

## Kurtarma paketi sozlesmesi

Her paket tek bir normal dizindir ve su uc dosyayi tasir:

- `database.sql`: tam D1 schema + veri exportu.
- `media-manifest.json`: yedek R2 kovasinda bulunmasi gereken hashli nesnelerin envanteri.
- `recovery-metadata.json`: iki artifact'in SHA-256 ozeti, tarih ve kanonik D1 tablo listesi.

JSON bicimi `docs/recovery-bundle.schema.json` ile surumlenir. Manifest satiri `key`, `kind`, tam `sha256`, `byteSize`, `contentType`, `width` ve `height` tasir. `objectCount` ve `totalBytes`, `entries` ile birebir uyusur. R2 yedekleme isi tam SHA-256 ozetini nesne kopyalanirken hesaplar; ETag checksum yerine kullanilmaz.

`database.sql` ve `media-manifest.json` hazir oldugunda metadata dosyasi yeni dosya olarak uretilir; mevcut metadata ezilmez:

```powershell
npm run recovery:prepare -- C:\guvenli-konum\panelya-2026-07-19
```

Sonraki paket dogrulamasi salt okunurdur:

```powershell
npm run recovery:verify -- C:\guvenli-konum\panelya-2026-07-19
```

Arac sembolik baglari, paket disina cikan dosya yollarini, beklenmeyen JSON alanlarini, eksik D1 tablolarini, tekrar eden/gecersiz R2 anahtarlarini ve checksum uyusmazligini reddeder. Basarili cikti yalniz tablo/nesne sayisi ve toplam byte verir; satir, anahtar veya kisi verisi basmaz.

## Production yedek alma

1. Dusuk trafik penceresi sec. D1 exportu surerken diger veritabani isteklerinin bloke olabilecegini operasyon kaydina yaz.
2. Mevcut D1 bookmark'ini guvenli operasyon kaydina al:

   ```powershell
   npx wrangler d1 time-travel info <D1_DATABASE_NAME>
   ```

3. Tam D1 exportunu Git disindaki yeni ve bos paket dizinine yaz:

   ```powershell
   npx wrangler d1 export <D1_DATABASE_NAME> --remote --output=<ABSOLUTE_BUNDLE_PATH>\database.sql
   ```

4. Canli `MEDIA` kovasindaki yeni hashli nesneleri ayri yedek kovasina kopyala. Yedek kimligi yalniz kaynak okumaya, hedefte create/list yapmaya yetkili olmali; canli kovada delete yetkisi olmamali. Kopya mevcutsa SHA-256 ve byte boyu ayni olmadan basarili sayma.
5. Kopyalama isi `media-manifest.json` dosyasini olustursun. D1 `media_assets.storage_key` ve `media_variants.storage_key` envanteri ile yedek kova listesi iki yonlu karsilastirilsin: D1'de olup yedekte olmayan ve yedekte olup manifestte olmayan nesne kalmasin.
6. `npm run recovery:prepare -- <ABSOLUTE_BUNDLE_PATH>` ile metadata olustur; sonra `npm run recovery:verify -- <ABSOLUTE_BUNDLE_PATH>` calistir.
7. Yalniz dogrulanan paketi sifreli, erisimi sinirli artifact deposuna tasi. SQL exportunu R2'de tutuyorsan medya canli kovasindan ayri yedek kovasini kullan.
8. Yedek kovasinda `media/` ve paket prefix'lerine uygun retention bucket lock uygula. Kilidi once kisa bir sentetik prefix'te dene; daha kati kuralin lifecycle kuralina baskin oldugunu ve kilitli nesnenin overwrite/delete edilemedigini kabul et.
9. Tarih, schemaVersion, nesne sayisi, toplam byte, D1 bookmark ve verifier sonucunu erisim kontrollu operasyon kaydina yaz. Secret, cookie, token, SQL satiri veya nesne anahtari yazma.

Canli `MEDIA` kovasina genel bucket lock uygulanmaz: upload hata telafisi yeni yazilan nesneyi silebilmelidir. Koruma, delete yetkisiz producer kimligi + hashli immutable anahtar + ayri kilitli yedek kovasi ile kurulur.

## Geri yukleme karari

- Yalniz D1 mantiksal hata ve zaman penceresi icindeyse Time Travel kullan.
- D1 kaybi/pencere disiysa dogrulanmis `database.sql` dosyasini bos ve izole bir D1 veritabanina import ederek prova et; dogrudan canli DB'ye ilk denemeyi yapma.
- R2 nesnesi eksikse yalniz eksik immutable anahtari yedek kovasindan geri getir. Mevcut anahtari farkli checksum ile asla ezme.
- D1 ve R2 birlikte geri donuyorsa ayni recovery bundle tarihini kullan; D1 manifest baglantilari ile R2 snapshot'i karistirma.

## D1 Time Travel geri donusu

Bu islem veritabanini yerinde ezer ve ucan sorgu/transaction'lari iptal eder. Kullanici onayi ve bakim penceresi olmadan calistirilmaz.

1. Yazma trafigini ve Queue consumer'i durdur.
2. Guncel bookmark'i ve mumkunse yeni tam exportu al; geri donusu geri alma noktasi olarak kaydet.
3. Hedef timestamp icin once bookmark'i gor:

   ```powershell
   npx wrangler d1 time-travel info <D1_DATABASE_NAME> --timestamp="<RFC3339_TIMESTAMP>"
   ```

4. Incident sahibi hedefi ikinci kez onayladiktan sonra restore komutunu elle calistir:

   ```powershell
   npx wrangler d1 time-travel restore <D1_DATABASE_NAME> --bookmark=<CONFIRMED_BOOKMARK>
   ```

5. Komutun dondurdugu onceki bookmark'i kaydet; bu, restore'u geri alma noktasidir.
6. Restore eski oturum, sifirlama/dogrulama tokeni, preview linki veya yonetici daveti diriltebilir. Trafik acilmadan once `sessions`, `account_tokens`, `preview_tokens` ve `rate_limit_buckets` temizlenir; bekleyen `admin_invitations` iptal edilir ve action URL tasiyan eski outbox kayitlari temizlenir. Bu guvenlik adimi audit olayiyla kaydedilir.
7. Kanonik tablo envanteri, admin sayisi, yayin katalog sayisi ve D1-R2 medya baglantilari aggregate olarak kontrol edilir. Kisi verisi loglanmaz.
8. `/api/catalog`, seri detayi, bir bolum manifesti, Studio platform readiness ve bir admin login smoke testi yapilir. Sonra Queue consumer, en son yazma trafigi acilir.

## SQL exporttan geri donus

1. `npm run recovery:verify -- <BUNDLE>` basarili olmadan import etme.
2. Yeni bos bir D1 kurtarma veritabani olustur ve importu once orada prova et:

   ```powershell
   npx wrangler d1 execute <RECOVERY_DATABASE_NAME> --remote --file=<ABSOLUTE_BUNDLE_PATH>\database.sql
   ```

3. Tablo/sayim ve uygulama smoke testleri prova DB'sinde gecmeden production binding'ini degistirme.
4. Binding degisikligi gerekiyorsa platform readiness kontrolu ve rollback binding'i ayni change kaydinda olsun.
5. Oturum/token/davet temizligini Time Travel prosedurundeki gibi uygula; sonra R2 manifest uyumunu kontrol et.

D1 import dosyasi 5 GiB sinirini asarsa parcala. Virtual table eklenirse D1 exportunun bunu desteklemedigini hesaba kat ve schema degisikligiyle birlikte bu runbook'u guncelle. Buyuk integer alanlari eklenirse JavaScript 52-bit hassasiyet sinirini ayrica test et.

## R2 geri donusu

1. Yedek kova ve manifest salt okunur kimlikle listelenir; restore kimligi canli kovada yalniz eksik nesne create edebilir.
2. Her nesne kopyadan once tam SHA-256 ve byte boyuyla manifestte dogrulanir.
3. Hedef anahtar varsa: checksum ayniysa atla; farkliysa incident'i durdur. Overwrite yapma.
4. Kopya sonrasi canli nesne tekrar hashlenir; D1'deki content type, boyut ve piksel metadata'siyla karsilastirilir.
5. Public endpoint yalniz halen yayina bagli varligi servis etmeye devam etmelidir. Yedekten donen yetim nesneyi public yapma.

## Tatbikat ve kabul

- Yerel otomatik test: `npm run test:recovery`.
- Artifact kontrolu: `npm run recovery:verify -- <SYNTHETIC_BUNDLE>`.
- Production-disinda aylik tatbikat: yeni D1'e import + ayri R2 test kovasina restore + uygulama smoke.
- Tatbikat sonucu `QA-OPS-02` olarak `docs/manual-qa-checklist.md` formatinda kaydedilir.

Basari kosulu: verifier yesil, kanonik 18 D1 tablosu mevcut, manifestte eksik/fazla nesne yok, public katalog/seri/bolum API'leri calisiyor, Studio admin girisi yeni oturumla yapiliyor, eski oturum/token/preview/davetler kullanilamiyor ve rollback noktasi kayitli.
