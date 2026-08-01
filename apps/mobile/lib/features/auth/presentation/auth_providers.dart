import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/auth_feature_config.dart';
import '../../../core/storage/token_store.dart';
import '../data/auth_browser.dart';
import '../data/http_auth_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session_state.dart';

/// Aktif [AuthRepository]. Gerçek `/api/auth/*` uçlarına konuşan
/// [HttpAuthRepository]'yi bağlar (bkz. o dosyadaki sınıf dokümantasyonu
/// — mantığı zaten ADR-039 sözleşmesine göre yazılmış). Hedef ortamın Auth0
/// tenant/gateway/JWKS değerleri eksikse web tarafı `/api/auth/config`'i
/// bilerek "fail closed" 503 döndürür; bu, ekranların dürüstçe "servis şu an
/// kullanılamıyor" göstermesiyle sonuçlanır — sahte bir "başarılı giriş"
/// GÖSTERİLMEZ.
///
/// Testlerde bu provider `FakeAuthRepository` (bkz. `data/
/// fake_auth_repository.dart`) ile override edilir; gerçek HTTP/secure
/// storage hiç çağrılmaz.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repository = HttpAuthRepository(
    client: ref.watch(apiClientProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

/// Sistem tarayıcısını açan aktif [AuthBrowser]. Gerçek [SystemAuthBrowser]
/// implementasyonunu (`flutter_web_auth_2`, bkz. o dosyadaki sınıf
/// dokümantasyonu) bağlar.
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
/// `enabled: true` olduğunda [authRepositoryProvider]'ın gerçek durum
/// akışına abone olur ve mevcut durumla başlar. Testler aynı provider'ı
/// `FakeAuthRepository` ile açıkça override eder.
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
