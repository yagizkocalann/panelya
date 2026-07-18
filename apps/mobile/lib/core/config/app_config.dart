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
  const AppConfig({required this.apiOrigin});

  factory AppConfig.fromDartDefines() {
    return const AppConfig(
      apiOrigin: String.fromEnvironment(
        'API_ORIGIN',
        defaultValue: 'http://localhost:3000',
      ),
    );
  }

  /// Web deployment'ının API sınırı. Mobil istemci D1/R2'ye doğrudan
  /// bağlanmaz; yalnız bu origin altındaki `/api/*` uçlarını kullanır.
  final String apiOrigin;
}

/// Aktif [AppConfig]. Testlerde override edilebilir; varsayılan olarak
/// dart-define değerlerini okur.
final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromDartDefines());
