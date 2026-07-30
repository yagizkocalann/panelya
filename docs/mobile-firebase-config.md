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

## Anahtar sızması durumunda

Bu dosyalardaki API anahtarı bir yere sızarsa dosyayı Git takibinden
çıkarmak **tek başına yeterli değildir** — anahtar geçmiş commit'lerde
okunabilir kalır. Google Cloud Console'da anahtarın döndürülmesi ve
uygulama/API kısıtlarının verilmesi gerekir. Depo temizliği ile anahtar
rotasyonu ayrı işlerdir; ikisi de yapılmadan sorun kapanmış sayılmaz.
