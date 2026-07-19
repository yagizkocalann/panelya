import 'package:flutter/foundation.dart';

import '../../../core/contracts/generated/generated.dart';

/// Panelya kullanıcısının mevcut oturum durumu (bkz. PLAN "mevcut AuthState
/// akışı").
///
/// Bilerek yalnız iki durum vardır — anonim ve kimliği doğrulanmış. Auth
/// özelliğinin hiç yapılandırılmadığı durum (bkz.
/// `core/config/auth_feature_config.dart` — `AuthFeatureConfig.enabled ==
/// false`) BURADA üçüncü bir varyant olarak MODELLENMEZ: sınırın en üst
/// katmanı (`authSessionProvider`, bkz.
/// `features/auth/presentation/auth_providers.dart`) yapılandırılmamışken
/// hiçbir repository/network çağrısı yapmadan doğrudan
/// [AuthSessionState.anonymous] üretir. Böylece "yapılandırılmamış" durumu,
/// bu sınıfın tükettiği her yerde zaten var olan "anonim" davranışına
/// (görünür auth butonu yok, ADR-010) sorunsuzca çakışır; ayrı bir
/// yapılandırılmamış dalı gerektirmez. Bir ekranın "neden giriş
/// yapılamıyor" gibi ayrıntı göstermesi gerekirse `AuthFeatureConfig.enabled`
/// bayrağı zaten ayrıca okunabilir durumdadır.
@immutable
sealed class AuthSessionState {
  const AuthSessionState();

  const factory AuthSessionState.anonymous() = AuthAnonymous;

  const factory AuthSessionState.authenticated(AuthUser user) =
      AuthAuthenticated;

  bool get isAuthenticated => this is AuthAuthenticated;
}

/// Hesapsız / çıkış yapılmış durum. Uygulama açılışındaki ve
/// logout/revoke sonrasındaki dinlenme durumu budur.
final class AuthAnonymous extends AuthSessionState {
  const AuthAnonymous();

  @override
  bool operator ==(Object other) => other is AuthAnonymous;

  @override
  int get hashCode => (AuthAnonymous).hashCode;

  @override
  String toString() => 'AuthAnonymous()';
}

/// Kimliği doğrulanmış durum. [user] yalnız Panelya kullanıcı özetini
/// taşır (bkz. `AuthUser` — Auth0 `sub` değeri asla buraya sızmaz);
/// erişim/refresh token'ları bu sınıfta DEĞİL, yalnız `TokenStore`
/// arkasında tutulur (bkz. `core/storage/token_store.dart`).
final class AuthAuthenticated extends AuthSessionState {
  const AuthAuthenticated(this.user);

  final AuthUser user;

  @override
  bool operator ==(Object other) =>
      other is AuthAuthenticated && other.user.id == user.id;

  @override
  int get hashCode => user.id.hashCode;

  @override
  String toString() => 'AuthAuthenticated(userId: ${user.id})';
}
