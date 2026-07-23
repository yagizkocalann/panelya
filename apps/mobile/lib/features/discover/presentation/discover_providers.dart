import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/provider_retry_policy.dart';
import '../../../core/contracts/generated/generated.dart';
import '../data/api_discover_repository.dart';
import '../domain/discover_repository.dart';

/// Aktif [DiscoverRepository]. `/catalog` ekranı (bkz.
/// `features/catalog/presentation/catalog_screen.dart`) `apiClientProvider`'ı
/// değil bu provider'ı kullanır.
final discoverRepositoryProvider = Provider<DiscoverRepository>((ref) {
  return ApiDiscoverRepository(ref.watch(apiClientProvider));
});

/// `GET /api/catalog` sonucu — tam katalog (`/catalog` ekranının arama ve
/// tür filtresinin uygulandığı kaynak liste). Ana sayfa artık bu provider'ı
/// DEĞİL, editorial `GET /api/discovery` cevabını (bkz.
/// `features/discovery/presentation/discovery_providers.dart` ->
/// `discoveryProvider`) kullanır. Loading/error/data durumları
/// `AsyncValue.when` ile ekranda gösterilir. Otomatik yeniden deneme
/// kapalıdır (bkz. `provider_retry_policy.dart`); tekrar deneme yalnız
/// kullanıcının "Tekrar dene" butonuyla `ref.invalidate` çağırmasıyla olur.
final catalogProvider = FutureProvider<CatalogResponse>(
  (ref) => ref.watch(discoverRepositoryProvider).fetchCatalog(),
  retry: noAutomaticRetry,
);
