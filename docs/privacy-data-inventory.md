# Panelya teknik veri envanteri

Bu belge Panelya kaynak kodunun 2026-08-02 tarihli teknik veri haritasidir.
Hukuki aydinlatma metni, isleme sarti veya kesin saklama taahhudu degildir.
Amaci production hukuk incelemesine gercek sistem davranisindan baslayan,
denetlenebilir bir girdi vermektir. Kodda uygulanmayan saklama suresi bu belgede
uygulanmis gibi yazilmaz.

## Temel sinirlar

- D1 kalici uygulama verisinin ana kaynagidir. R2 yalniz icerik medyasini tutar.
- Auth0 kimlik dogrulama saglayicisidir. Provider access/refresh tokenlari,
  authorization code veya PKCE verifier D1'e yazilmaz.
- Ham oturum, sifirlama, davet, onizleme ve yeniden dogrulama anahtarlari yerine
  yalniz hash saklanir.
- Sunucu FCM cihaz tokeni toplamaz; mobil uygulama sabit
  `panelya-new-episodes` konusuna dogrudan abone olur.
- Kalite olayi allowlist'i e-posta, kullanici/oturum kimligi, IP, user-agent,
  referrer, query/hash, hata mesaji ve stack kabul etmez.
- Yedek SQL ve R2 manifesti kisi verisi icerebilir; Git, issue, sohbet, normal
  log veya ekran goruntusune eklenmez.

## D1 tablo envanteri

| Tablo | Teknik veri ve amac | Bugunku yasam dongusu | Erisim siniri |
| --- | --- | --- | --- |
| `users` | E-posta, gorunen ad, yerel parola ozeti, rol, dogrulama ve hesap durumu | Hesap silmede e-posta rastgele `deleted.invalid` adresine, ad `Silinmis hesap` degerine, parola kullanilamaz ozete doner; satir silinmis durumunda kalir | Hesap sahibi ozet ucu; yoneticiler Studio envanteri |
| `provider_identities` | Auth0 issuer, hashlenmis subject, provider turu ve son giris zamani | Hesap silmede kayit silinir; ham provider subject saklanmaz | Server-only kimlik esleme |
| `sessions` | Hashli oturum anahtari, public/Studio kapsami, zamanlar ve sinirli user-agent | Sure/idle dolumunda dogrulama sirasinda silinir; cikis, sifre yenileme, rol degisimi ve hesap silme de temizler | Hesap sahibi oturum listesi; yonetici sayim/guvenlik islemi |
| `account_tokens` | Hashli e-posta dogrulama ve sifre sifirlama anahtari, hedef e-posta, son kullanim | E-posta dogrulama 24 saat, sifre sifirlama 30 dakika gecerli ve tek kullanimlidir; hesap silmede silinir. Sure dolan/kullanilan kaydin fiziksel periyodik purge karari aciktir | Server-only auth akisi |
| `account_reauthentication_requests` | Amac, web/mobil tasima, callback, PKCE challenge ile hashli state/nonce | En cok 10 dakika, tek kullanim; hesap silmede silinir. Sure dolan kayit purge takvimi aciktir | Server-only hesap guvenligi |
| `account_reauthentication_tokens` | Hashli, amaca bagli tek kullanimlik hesap kaniti | En cok 10 dakika, tek kullanim; hesap silmede silinir. Sure dolan kayit purge takvimi aciktir | Server-only hesap mutation'i |
| `account_deletion_requests` | Hashli idempotency anahtari, islem durumu, deneme ve sabit hata kodu | Tamamlanan/basarisiz saga kaydi operasyon ve denetim icin kalir; kesin saklama suresi hukuk/operasyon karari bekler | Hesap silme runtime'i ve yetkili incident incelemesi |
| `notification_outbox` | Alici, konu/govde, opsiyonel action URL, durum ve dedupe anahtari | Acilan 1 gun; bekleyen sifre 1, dogrulama/davet 2, yeni bolum 7, diger guvenlik 30 gun sonra manuel purge edilebilir. Hesap silmede kullaniciya bagli kayitlar silinir | Studio outbox ve teslim adapteri |
| `admin_invitations` | Davet e-postasi, hashli anahtar, davet eden, durum ve zamanlar | Anahtar 24 saat gecerli ve tek kullanimlidir; kabul/iptal kaydi kalir. Fiziksel saklama suresi aciktir | Studio yoneticileri ve davet kabul ucu |
| `rate_limit_buckets` | Turetilmis kota anahtari, sayac ve reset zamani | Reset sonrasi yeni pencereyle guncellenir; eski bucket fiziksel temizleme takvimi aciktir | Server-only guvenlik katmani |
| `library_items` | Kullanici-seri eslesmesi, okuma durumu ve favori | Kullanici kaldirinca veya hesap silmede fiziksel silinir | Hesap sahibi |
| `series_subscriptions` | Seri takibi ve yeni bolum bildirim tercihi | Takip kapatilinca veya hesap silmede fiziksel silinir | Hesap sahibi; yayin fan-out sorgusu |
| `reading_progress` | Seri/bolum konumu, baslik, numara, yuzde ve guncelleme zamani | Yeni konumla ezilir; hesap silmede fiziksel silinir | Hesap sahibi |
| `audit_events` | Sabit aksiyon adi, allowlist metadata, opsiyonel aktor baglantisi ve zaman | Hesap silmede `user_id` null olur; kayit operasyon/yasal denetim icin kalir. Kesin saklama suresi aciktir | Yetkili Studio audit ekrani |
| `contact_messages` | Ad, e-posta, konu, serbest metin mesaj ve islem durumu | Studio'da ele alindi durumu vardir; otomatik silme/saklama suresi henuz yoktur | Yetkili Studio mesaj ekrani |
| `copyright_notices` | Basvuran ad/e-posta/rol, eser ve URL'ler, hak aciklamasi, durum ve public yanit | Gizli durum baglantisi 90 gun gecerli; vaka kaydinin karsi bildirim ve yasal saklama suresi hukuk incelemesi bekler | Yetkili Studio telif ekrani; hashli gizli durum ucu |
| `reviews` | Seri puani, opsiyonel yorum, spoiler ve moderasyon durumu | Kullanici kendi incelemesini silebilir. Hesap silmede katkilar silinmis profil satirina bagli kalarak anonim gorunur; kesin saklama karari aciktir | Public yayin gorunumu; sahibi mutation; Studio moderasyon |
| `review_reports` | Raporlayan, sebep, opsiyonel detay ve moderasyon durumu | Hesap silmede raporlayan kullaniciya ait kayit silinir; cozulmus rapor saklama suresi aciktir | Raporlayan mutation; Studio moderasyon |
| `review_replies` | Yorum yaniti, yazar ve moderasyon durumu | Kullanici kendi yanitini silebilir. Hesap silmede silinmis profil satirina bagli anonim katkidir; kesin saklama karari aciktir | Public yayin gorunumu; sahibi mutation; Studio moderasyon |
| `review_likes` | Kullanici-yorum begeni eslesmesi | Kullanici kaldirinca veya hesap silmede fiziksel silinir | Hesap sahibi mutation; toplu sayim |
| `user_blocks` | Engelleyen-engellenen hesap eslesmesi | Kullanici kaldirinca veya iki taraftan biri hesabini silince fiziksel silinir | Hesap sahibi |
| `content_series` | Editorial seri metadata'si, yayin durumu, turler ve kapak baglantisi | Studio yayin arsivi; kisi verisi amaclanmaz. Creator alanina kisi verisi girilecekse hak/rol kaynagi ayrica kaydedilmelidir | Public yayin ve Studio icerik ekibi |
| `content_episodes` | Bolum metadata'si, panel manifesti ve yayin zamanlari | Studio yayin arsivi; kisi verisi amaclanmaz | Public yayin ve Studio icerik ekibi |
| `media_assets` | R2 anahtari, orijinal dosya adi, MIME/boyut/piksel, yukleyen admin | Icerik kaydi silinince metadata cascade olur; R2 kaynak nesnesinin yedek/lifecycle politikasi ayrica uygulanir. Dosya adinda kisi verisi kullanilmaz | Public yalniz yayina bagli medya; Studio medya ekibi |
| `media_variants` | Responsive WebP R2 anahtari ve teknik boyutlar | Kaynak asset silinince metadata cascade olur; R2 lifecycle/yedek politikasi ayridir | Public yayina bagli varyant; Studio medya ekibi |
| `media_derivative_jobs` | Turetme hedefi, durum, deneme ve serbest olmayan operasyonel hata alani | Asset silinince cascade olur; tamamlanan/basarisiz is saklama suresi aciktir | Studio medya/QA ve Queue consumer |
| `preview_tokens` | Hashli onizleme anahtari, seri/bolum kapsami, olusturan ve zamanlar | 30 dakika gecerli, iptal edilebilir; ham anahtar saklanmaz. Sure dolan kayit purge takvimi aciktir | Studio ve no-store onizleme ucu |

## D1 disi veri ve teknik servis siniri

| Katman | Giden/tutulan veri | Mevcut koruma ve acik karar |
| --- | --- | --- |
| Auth0 | Giriş kimligi, e-posta/profil, provider oturum/device credential bilgisi | Panelya serveri provider tokenlarini kalici saklamaz. Tenant bolgesi, Auth0 log saklama/erisim, sosyal provider sozlesmesi ve kullanici taleplerinin iki sistemde birlikte yurutulmesi production incelemesine girer |
| Cloudflare R2 | Kaynak kapak/panel ile responsive turevler | Yalniz icerik medyasi amaclanir; canli ve ayri immutable yedek kovasi lifecycle/lock karari production'da provision edilir |
| Cloudflare Queue/Images | Asset/is kimligi ve hedef teknik varyant; donusturulecek medya | Kisi/oturum verisi kuyruk zarfinda tasinmaz; retry, DLQ ve kota politikasi deployment smoke bekler |
| Cloudflare Workers Logs | Allowlist kalite olayi ve serbest metinsiz operasyonel hata adi | Invocation logs ve tracing kapali; Free 3/Paid 7 gun dogal saklama, dis export yok. Canli dashboard erisim/alarm smoke bekler |
| Firebase Cloud Messaging | Sabit topic, bildirim baslik/govde ve deep link | Panelya backend'i cihaz tokeni saklamaz. APNs/fiziksel cihaz ve production servis hesabi erisim politikasi bekler |
| Google reklam test agi | Yalniz localhostta resmi test birimi ve cihaz-yerel consent sonrasi reklam istegi | Production hostta fail-closed disabled. Gercek reklam/CMP/provider ve bolgesel onay ayri urun-hukuk kararidir |
| E-posta teslimi | Alici, bildirim metni ve opsiyonel tek kullanimlik action URL | Su an D1 local outbox; canli saglayici secilmedi. Saglayici saklama, webhook, suppression ve bolge envanteri secimle birlikte eklenir |
| Tarayici/mobil cihaz | Cihaz-yerel consent ve anonim okuma ilerlemesi; mobil secure storage'da Auth0 tokenlari | Panelya server envanterinden ayridir. Kullanici temizleme/uygulama kaldirma davranisi platform QA'sinda dogrulanir; token loglanmaz |

## Hesap silme ve kullanici kontrolleri

- Profil ve salt okunur e-posta: `GET /api/account`, profil mutation'i
  `PATCH /api/account/profile`.
- Sifre: Panelya formda mevcut/yeni production parolasi almaz; Auth0 database
  kullanicisina yenileme e-postasi ister.
- Oturumlar: tekil veya toplu iptal, sunucunun `currentSessionRevoked` sonucuyla
  yerel cikis kararini verir.
- Kutuphane, favori, takip, ilerleme ve engel kayitlari kullanici tarafindan
  yonetilebilir ve hesap silmede fiziksel silinir.
- Hesap silme taze Auth0 PKCE yeniden dogrulamasi ve idempotency anahtari ister;
  Auth0 kimligini siler, profili temizler, aktif oturumlari ve kisisel okuma
  verisini siler, topluluk katkilarini silinmis profile bagli anonim gorunume
  cevirir, audit aktor bagini koparir.
- Iletisim mesaji ve telif vakasi icin otomatik self-service silme ucu yoktur;
  talep kanali, kimlik dogrulama ve yasal istisna proseduru hukuk/operasyon
  incelemesinde kesinlesmelidir.

## Production oncesi acik kararlar

1. Veri sorumlusu/irtibat, isleme amaclari ve hukuki dayanaklar hukuk tarafindan
   onaylanacak; bu teknik envanter tek basina aydinlatma metni olmayacak.
2. `contact_messages`, cozulmus telif/moderasyon kayitlari, admin davetleri,
   sure dolmus token/preview/reauth kayitlari, rate-limit bucket'lari,
   tamamlanan medya isleri, `audit_events` ve `account_deletion_requests` icin
   kesin saklama + otomatik purge matrisi belirlenecek.
3. Silinmis hesap topluluk katkilarinin ne kadar tutulacagi, kullaniciya hangi
   istisnalarin nasil anlatilacagi ve audit/yasal kayit minimizasyonu onaylanacak.
4. D1 export/R2 yedek 90 gun hedefi canli trafik, maliyet ve mevzuat sonucu
   yeniden onaylanacak; silme taleplerinin yedeklerdeki davranisi belirlenecek.
5. Auth0, Cloudflare, Firebase ve secilecek e-posta/reklam hizmetlerinin bolge,
   alt hizmet, erisim, ihlal ve silme sozlesmeleri kaydedilecek.
6. Public `/privacy`, `/terms` ve `/copyright` metinleri bu kararlar tamamlanmadan
   production hukuki metni olarak sunulmayacak.

## Degisiklik kapisi

Yeni D1 tablosu ekleyen migration ayni PR'da bu envanteri gunceller. Otomatik
test `db/schema.ts` icindeki her `sqliteTable` adinin bu belgede bulunmasini
zorunlu tutar. Yeni dis servis, log exportu, analytics olayi veya kisi verisi
alani da ilgili teknik servis/veri satirini ve silme-saklama etkisini gunceller.
