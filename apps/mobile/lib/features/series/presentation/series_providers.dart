import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/provider_retry_policy.dart';
import '../../../core/contracts/series_detail_response.dart';
import '../data/api_series_repository.dart';
import '../domain/series_repository.dart';

final seriesRepositoryProvider = Provider<SeriesRepository>((ref) {
  return ApiSeriesRepository(ref.watch(apiClientProvider));
});

/// `GET /api/series/:slug` sonucu, seri slug'ına göre. Otomatik yeniden
/// deneme kapalıdır (bkz. `core/api/provider_retry_policy.dart`) — 404
/// (`series_not_found`) gibi kalıcı hatalar hemen ekrana yansır.
final seriesDetailProvider = FutureProvider.family<SeriesDetailResponse, String>(
  (ref, slug) => ref.watch(seriesRepositoryProvider).fetchSeriesDetail(slug),
  retry: noAutomaticRetry,
);
