import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/auth_feature_config.dart';
import '../../../core/storage/token_store.dart';
import '../data/auth_browser.dart';
import '../data/fake_auth_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session_state.dart';

/// Aktif [AuthRepository]. BUGÜN YALNIZ [FakeAuthRepository]'yi bağlar
/// (bkz. görev talimatı madde 2 — testler ve geliştirme için in-memory
/// sahte). Gerçek Auth0 tenant/gateway/JWKS değerleri sağlandığında geçiş
/// TEK NOKTADAN yapılır: bu provider'ın gövdesi `HttpAuthRepository(...)`
/// örneklemesiyle değiştirilir (bkz. `data/http_auth_repository.dart`
/// sınıf dokümantasyonu); çağıran kod (`authSessionProvider` ve ileride
/// eklenecek ekranlar) DEĞİŞMEZ.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repository = FakeAuthRepository(tokenStore: ref.watch(tokenStoreProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

/// Sistem tarayıcısını açan aktif [AuthBrowser]. Bugün yalnız [SystemAuthBrowser]
/// stub'ını bağlar (bkz. o dosyadaki sınır notu); `HttpAuthRepository`
/// devreye alındığında gerçek bir implementasyonla değiştirilecektir.
final authBrowserProvider = Provider<AuthBrowser>((ref) => const SystemAuthBrowser());

/// Auth sınırının ekranların tüketeceği TEK giriş noktası.
///
/// [AuthFeatureConfig.enabled] `false` (varsayılan, bkz.
/// `core/config/auth_feature_config.dart`) iken bu provider [authRepositoryProvider]'ı
/// hiç `watch` ETMEZ — hiçbir repository örneklenmez, hiçbir network/secure
/// storage erişimi denenmez; durum her zaman [AuthAnonymous] olarak kalır.
/// Bu, ADR-010'un "yapılandırılmamışken hiçbir görünür auth butonu/
/// placeholder yok" kuralının sınır katmanındaki karşılığıdır: ileride
/// eklenecek bir ekran yalnız bu provider'ı okuyarak zaten doğru davranır,
/// ayrıca `AuthFeatureConfig`'i kontrol etmesi gerekmez.
///
/// `enabled: true` olduğunda (bugün yalnız testlerde override edilerek)
/// [authRepositoryProvider]'ın durum akışına abone olur ve mevcut durumla
/// başlar.
final authSessionProvider = NotifierProvider<AuthSessionNotifier, AuthSessionState>(
  AuthSessionNotifier.new,
);

class AuthSessionNotifier extends Notifier<AuthSessionState> {
  StreamSubscription<AuthSessionState>? _subscription;

  @override
  AuthSessionState build() {
    ref.onDispose(() => _subscription?.cancel());

    final previousSubscription = _subscription;
    _subscription = null;
    if (previousSubscription != null) {
      previousSubscription.cancel();
    }

    final config = ref.watch(authFeatureConfigProvider);
    if (!config.enabled) {
      return const AuthSessionState.anonymous();
    }

    final repository = ref.watch(authRepositoryProvider);
    _subscription = repository.stateChanges.listen((next) => state = next);
    return repository.currentState;
  }
}
