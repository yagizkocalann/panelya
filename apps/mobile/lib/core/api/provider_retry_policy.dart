/// Riverpod 3'ün varsayılan davranışı her `FutureProvider` hatasını
/// (üstel geri çekilmeyle, varsayılan 10 denemeye kadar) sessizce otomatik
/// tekrar dener — bu, bir 404 (`series_not_found`/`episode_not_found` gibi
/// kalıcı bir istemci hatası) için bile onlarca saniye boyunca kullanıcıya
/// hiçbir şey göstermeden beklemek anlamına gelir.
///
/// Panelya'nın kendi [ApiException] hiyerarşisi zaten network/4xx/5xx/parse
/// ayrımını yapıyor ve her ekranda açık bir "Tekrar dene" butonu var
/// (bkz. `shared/widgets/state_views.dart`); bu yüzden veri sağlayıcıları
/// Riverpod'un örtük yeniden deneme mekanizmasını kapatır ve hatayı hemen
/// `AsyncError` olarak yüzeye çıkarır. Tek yeniden deneme yolu kullanıcının
/// dokunduğu buton üzerinden `ref.invalidate(...)` çağırmaktır.
Duration? noAutomaticRetry(int retryCount, Object error) => null;
