import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/provider_retry_policy.dart';
import '../../../core/contracts/catalog_response.dart';
import '../data/api_discover_repository.dart';
import '../domain/discover_repository.dart';

/// Aktif [DiscoverRepository]. Ekranlar `apiClientProvider`'ı değil bu
/// provider'ı kullanır.
final discoverRepositoryProvider = Provider<DiscoverRepository>((ref) {
  return ApiDiscoverRepository(ref.watch(apiClientProvider));
});

/// `GET /api/catalog` sonucu; loading/error/data durumları
/// `AsyncValue.when` ile ekranda gösterilir. Otomatik yeniden deneme
/// kapalıdır (bkz. `provider_retry_policy.dart`); tekrar deneme yalnız
/// kullanıcının "Tekrar dene" butonuyla `ref.invalidate` çağırmasıyla olur.
final catalogProvider = FutureProvider<CatalogResponse>(
  (ref) => ref.watch(discoverRepositoryProvider).fetchCatalog(),
  retry: noAutomaticRetry,
);

/// Seçili tür filtresi (istemci tarafı, bkz. `discover_filters.dart`).
/// `null` = "Tümü". Arama kapsam dışıdır (bkz. PLAN Görev 2).
final selectedGenreProvider = StateProvider<String?>((ref) => null);
