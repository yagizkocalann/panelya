# Mobil Firebase istemci yapılandırması

Flutter uygulaması (`apps/mobile`) push bildirimleri için Firebase istemci
yapılandırma dosyalarına ihtiyaç duyar. **Bu dosyaların gerçekleri Git'e
commit edilmez** — depoda yalnız bu doküman bulunur.

Yeni bir clone'da mobil uygulamayı çalıştırmadan önce iki dosyanın da
yerine konması gerekir; aksi hâlde Android build'i Google Services
eklentisinde, iOS build'i ise çalışma anında Firebase başlatılırken
hata verir.

## Hedef yollar

| Platform | Dosya | Yol |
| --- | --- | --- |
| Android | `google-services.json` | `apps/mobile/android/app/google-services.json` |
| iOS | `GoogleService-Info.plist` | `apps/mobile/ios/Runner/GoogleService-Info.plist` |

Her iki yol da kök `.gitignore` içinde tam yol olarak listelidir. Dosya
adlarını veya konumlarını değiştirme: Android tarafında Google Services
Gradle eklentisi, iOS tarafında ise `Runner` hedefinin Resources build
phase'i bu adları sabit olarak bekler.

## Dosyaları edinme

1. [Firebase Console](https://console.firebase.google.com/) üzerinde
   projeyi aç.
2. **Project settings → Your apps** bölümüne git.
3. Android uygulaması için `google-services.json`, iOS uygulaması için
   `GoogleService-Info.plist` dosyasını indir. Bunlar Console tarafından
   üretilir; elle yazılmaz.
4. İndirilen dosyaları yukarıdaki tabloda verilen yollara, adlarını
   değiştirmeden koy.

Hangi Firebase projesinin/uygulamasının kullanılacağını ekipten al. Proje
kimliği, paket adı/bundle id eşleşmesi ve API anahtarları bu dokümanda
**bilinçli olarak yazılmaz**.

## İçerik hakkında

Dosyaların şemasını burada örneklemiyoruz ve depoda `.example` karşılıkları
tutmuyoruz — bu dosyalar Console'un ürettiği bütünlüklü yapılandırmalardır,
alan alan doldurulmaz. İkisi de proje kimliği, uygulama kimliği ve bir
Google API anahtarı taşır; bu yüzden gizli kabul edilir ve GitHub secret
scanning tarafından tespit edilir.

## CI ve release

CI ve release build'lerinde bu dosyalar depodan gelmez. Her iki dosya
encrypted secret olarak saklanır ve build adımının başında hedef yollarına
yazılır. Secret'lar yalnız build sırasında çözülür; iş akışı loglarına
yazdırılmaz ve artifact olarak dışa aktarılmaz.

### Enjeksiyon sınırı (netleştirme)

Bugünkü `Mobile quality` GitHub Actions işi (`.github/workflows/quality.yml`)
yalnız `flutter analyze` ve `flutter test` çalıştırır; bir release derlemesi
(`assembleRelease`/`bundleRelease`) tetiklemez ve bu iki Firebase dosyasına
ihtiyaç duymaz — bu yüzden bugün CI'da bu dosyaları enjekte eden bir adım
yoktur. Bu sınır, bir release-build iş akışı eklendiğinde geçerli olacak
kural şudur:

- Enjeksiyon adımı, Android/iOS **release derleme görevinden hemen önce**
  çalışır; dosyalar yalnız o iş çalışırken diskte durur, workflow bitince
  runner ile birlikte silinir. Depoya veya paylaşılan bir cache'e yazılmaz.
- Android tarafında `google-services.json`, Google Services Gradle
  eklentisi *configuration* aşamasında dosyayı okuduğu için build
  başlamadan önce, en geç `flutter pub get` sonrası ve gradle
  invocation'ından önce yerinde olmalıdır.
- iOS tarafında `GoogleService-Info.plist`, `Runner` hedefinin Resources
  build phase'i tarafından paketlendiği için Xcode arşivleme adımından
  önce yerinde olmalıdır.
- Bu iki dosya, Android release **imzalama** materyalinden (`android/key.properties`
  veya `PANELYA_ANDROID_*` ortam değişkenleri — bkz. `apps/mobile/README.md`
  "Release imzalama (fail-closed)") **ayrı bir secret sınıfıdır**: Firebase
  dosyaları istemci yapılandırmasıdır (API anahtarı taşır ama uygulamaya
  gömülmesi zaten amaçlanır), keystore ise imzalama materyalidir (asla
  istemciye gömülmez, yalnız build makinesinde kullanılır). İkisi aynı
  secret deposunda tutulabilir ama aynı enjeksiyon adımıyla karıştırılmaz;
  her biri kendi hedef yoluna/ortam değişkenine ayrı yazılır.

## Anahtar sızması durumunda

Bu dosyalardaki API anahtarı bir yere sızarsa dosyayı Git takibinden
çıkarmak **tek başına yeterli değildir** — anahtar geçmiş commit'lerde
okunabilir kalır. Google Cloud Console'da anahtarın döndürülmesi ve
uygulama/API kısıtlarının verilmesi gerekir. Depo temizliği ile anahtar
rotasyonu ayrı işlerdir; ikisi de yapılmadan sorun kapanmış sayılmaz.
