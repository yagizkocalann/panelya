import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Auth ozelliginin ana acma/kapama anahtari.
///
/// Gercek Auth0 Authorization Code + PKCE istemcisi ve web token gateway'i
/// hazirdir (bkz. ADR-039, docs/production-auth-session.md). Web tarafi
/// gateway'i sunucu ortaminda `AUTH0_GATEWAY_ENABLED` ile korur; mobil taraf
/// gorunur auth ozelligini derleme-zamani dart-define katmaninda acar —
/// sabit kod DEGIL, `--dart-define=AUTH_ENABLED=true` veya `env/*.json`
/// icinde `"AUTH_ENABLED": true` ile enjekte edilir.
///
/// `enabled == false` (varsayilan) iken auth sinirinin en ust katmani
/// ([features/auth/presentation/auth_providers.dart] icindeki
/// `authSessionProvider`) hicbir repository/network cagrisi yapmadan hep
/// anonim durumda kalir; bu, ADR-010'un gerektirdigi "yapilandirilmamisken
/// hicbir gorunur auth butonu/placeholder yok" davranisinin sinir
/// katmanindaki karsiligidir. Login ve Hesabim ekranlari bu provider
/// uzerinden ayni yayin kapisina uyar.
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

/// Aktif [AuthFeatureConfig]. Testler bu config'i ve gerekli repository'leri
/// acikca override edebilir; runtime ise dart-define verilmezse fail-closed
/// varsayilan `false` degerinde kalir.
final authFeatureConfigProvider = Provider<AuthFeatureConfig>(
  (ref) => AuthFeatureConfig.fromDartDefines(),
);
