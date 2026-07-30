import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Derleme zamanı ortam yapılandırması.
///
/// Değerler `--dart-define-from-file=env/<isim>.json` ile enjekte edilir
/// (örn. `env/local.json`). API origin'i hiçbir zaman kaynak koda gömülmez
/// (bkz. docs/mobile-handoff.md, Ortaklık kuralları #6); bir define
/// verilmezse `apiOrigin` yerel web geliştirme sunucusuna
/// (`http://localhost:3000`) düşer.
///
/// Fiziksel cihazda test ederken `localhost` telefonun kendisini işaret
/// eder, Mac'i değil. `env/local.json` içindeki `API_ORIGIN` değerini
/// Mac'in yerel ağ adresine (örn. `http://192.168.1.23:3000`) ayarlayın;
/// bkz. `apps/mobile/README.md`.
@immutable
class AppConfig {
  const AppConfig({required this.apiOrigin, required this.webOrigin});

  factory AppConfig.fromDartDefines() {
    const apiOrigin = String.fromEnvironment(
      'API_ORIGIN',
      defaultValue: 'http://localhost:3000',
    );
    const webOrigin = String.fromEnvironment('WEB_ORIGIN');
    return AppConfig(
      apiOrigin: apiOrigin,
      // Define verilmezse `apiOrigin`e düşülür (bkz. [webOrigin]).
      webOrigin: webOrigin.isEmpty ? apiOrigin : webOrigin,
    );
  }

  /// Web deployment'ının API sınırı. Mobil istemci D1/R2'ye doğrudan
  /// bağlanmaz; yalnız bu origin altındaki `/api/*` uçlarını kullanır.
  final String apiOrigin;

  /// Herkese açık web sitesinin origin'i — yasal sayfalar (gizlilik,
  /// kullanım koşulları, telif bildirimi) buradan açılır.
  ///
  /// `WEB_ORIGIN` define'ı verilmezse [apiOrigin]'e düşer: yerel
  /// geliştirmede ve tek origin'li deployment'ta ikisi AYNIDIR. Ayrı bir
  /// domain kullanılacaksa (ör. API başka bir alt alan adındaysa) define
  /// açıkça verilmelidir — burada tahmin YAPILMAZ.
  final String webOrigin;
}

/// Aktif [AppConfig]. Testlerde override edilebilir; varsayılan olarak
/// dart-define değerlerini okur.
final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromDartDefines());
