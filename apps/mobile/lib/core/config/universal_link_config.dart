import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Universal Links (iOS) / App Links (Android) için izin verilen host
/// allowlist'i (bkz. `app/router/router.dart` -> `redirect`,
/// `app/router/deep_link.dart` -> `mapWebPathToMobileRoute`,
/// `apps/mobile/README.md` "Gelecek adım").
///
/// Production domain kararı HENÜZ verilmedi (bkz. production-bible.md ADR),
/// bu yüzden burada hiçbir domain sabit kodlanmaz. Değer, derleme zamanında
/// `--dart-define=UNIVERSAL_LINK_HOSTS=<host1>,<host2>` (veya
/// `env/*.json` içinde `"UNIVERSAL_LINK_HOSTS": "<host1>,<host2>"`) ile
/// enjekte edilir; birden fazla host virgülle ayrılır (örn. production +
/// staging domainleri).
///
/// FAIL-CLOSED tasarım: define verilmezse [allowedHosts] BOŞ küme olur ve
/// [isAllowedHost] her zaman `false` döner — yani hiçbir `https`/`http`
/// deep-link kabul edilmez, hepsi güvenli düşüşe (keşif) gider. Bu, bilinmeyen
/// bir domain'in (veya define hiç ayarlanmamışken HERHANGİ bir domain'in)
/// sessizce kabul edilmesini engeller.
@immutable
class UniversalLinkConfig {
  const UniversalLinkConfig({required this.allowedHosts});

  factory UniversalLinkConfig.fromDartDefines() {
    const raw = String.fromEnvironment('UNIVERSAL_LINK_HOSTS');
    final hosts = raw
        .split(',')
        .map((host) => host.trim().toLowerCase())
        .where((host) => host.isNotEmpty)
        .toSet();
    return UniversalLinkConfig(allowedHosts: hosts);
  }

  /// Küçük harfe çevrilmiş, izin verilen host kümesi. Boşsa (varsayılan)
  /// hiçbir host kabul edilmez.
  final Set<String> allowedHosts;

  /// [host] (case-insensitive) allowlist'te mi. Boş bir host (`''`) hiçbir
  /// zaman kabul edilmez, allowlist boş olsa bile.
  bool isAllowedHost(String host) {
    final normalized = host.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return allowedHosts.contains(normalized);
  }
}

/// Aktif [UniversalLinkConfig]. Testler bu config'i açıkça override eder;
/// runtime ise dart-define verilmezse fail-closed varsayılan (boş allowlist)
/// değerinde kalır.
final universalLinkConfigProvider = Provider<UniversalLinkConfig>(
  (ref) => UniversalLinkConfig.fromDartDefines(),
);
