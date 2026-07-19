import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Auth ozelliginin ana acma/kapama anahtari.
///
/// Gercek Auth0 tenant/gateway/JWKS entegrasyonu henuz saglanmadi (bkz.
/// ADR-039, docs/production-auth-session.md "Kalan deployment kapilari").
/// Web tarafi ayni anahtari sunucu ortaminda `AUTH0_GATEWAY_ENABLED` olarak
/// tutar (bkz. `app/lib/production-auth.ts`); mobil taraf ayni deseni
/// derleme-zamani dart-define katmaninda tekrarlar — sabit kod DEGIL,
/// `--dart-define=AUTH_ENABLED=true` veya `env/*.json` icinde
/// `"AUTH_ENABLED": true` ile enjekte edilir.
///
/// `enabled == false` (varsayilan) iken auth sinirinin en ust katmani
/// ([features/auth/presentation/auth_providers.dart] icindeki
/// `authSessionProvider`) hicbir repository/network cagrisi yapmadan hep
/// anonim durumda kalir; bu, ADR-010'un gerektirdigi "yapilandirilmamisken
/// hicbir gorunur auth butonu/placeholder yok" davranisinin sinir
/// katmanindaki karsiligidir (bu paket bir UI ekrani icermez, ama ileride
/// eklenecek ekran bu bayragi/`authSessionProvider`'i kullanarak ayni
/// kurala uyacaktir).
@immutable
class AuthFeatureConfig {
  const AuthFeatureConfig({required this.enabled});

  factory AuthFeatureConfig.fromDartDefines() {
    return const AuthFeatureConfig(
      enabled: bool.fromEnvironment('AUTH_ENABLED'),
    );
  }

  final bool enabled;
}

/// Aktif [AuthFeatureConfig]. Testlerde `enabled: true` ile override edilip
/// [FakeAuthRepository] uzerinden akis test edilir; override edilmezse
/// varsayilan `false` kalir.
final authFeatureConfigProvider = Provider<AuthFeatureConfig>(
  (ref) => AuthFeatureConfig.fromDartDefines(),
);
