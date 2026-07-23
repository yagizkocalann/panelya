import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/provider_retry_policy.dart';
import '../../../core/contracts/generated/generated.dart';
import '../data/api_discovery_repository.dart';
import '../domain/discovery_repository.dart';

/// Aktif [DiscoveryRepository]. Ekranlar `apiClientProvider`'ı değil bu
/// provider'ı kullanır.
final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  return ApiDiscoveryRepository(ref.watch(apiClientProvider));
});

/// `GET /api/discovery` sonucu; loading/error/data durumları
/// `AsyncValue.when` ile ekranda gösterilir. Otomatik yeniden deneme
/// kapalıdır (bkz. `provider_retry_policy.dart`); tekrar deneme yalnız
/// kullanıcının "Tekrar dene" butonuyla `ref.invalidate` çağırmasıyla olur.
final discoveryProvider = FutureProvider<DiscoveryResponse>(
  (ref) => ref.watch(discoveryRepositoryProvider).fetchDiscovery(),
  retry: noAutomaticRetry,
);
