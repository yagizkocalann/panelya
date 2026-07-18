import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_error_presenter.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/series_card.dart';
import '../../../shared/widgets/state_views.dart';
import 'discover_providers.dart';

/// Keşif ekranı (`/`): `GET /api/catalog`'dan gelen seri kartlarının basit
/// bir listesi. Faz 1'de yalnız yükleniyor/hata/boş/başarı iskeleti kurulur;
/// öne çıkan seri vurgusu, tür filtreleri ve arama Faz 2'nin işidir.
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final catalog = ref.watch(catalogProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Panelya')),
      body: SafeArea(
        child: catalog.when(
          loading: () => const AppLoadingView(label: 'Katalog yükleniyor'),
          error: (error, stackTrace) => AppErrorView(
            message: error is ApiException
                ? describeApiException(error)
                : 'Beklenmeyen bir hata oluştu.',
            onRetry: () => ref.invalidate(catalogProvider),
          ),
          data: (response) {
            if (response.series.isEmpty) {
              return const AppEmptyView(
                message: 'Henüz yayınlanmış bir seri yok.',
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref.refresh(catalogProvider.future),
              child: ListView.separated(
                padding: EdgeInsets.all(tokens.spacing.md),
                itemCount: response.series.length,
                separatorBuilder: (context, index) =>
                    SizedBox(height: tokens.spacing.md),
                itemBuilder: (context, index) {
                  final series = response.series[index];
                  return SeriesCard(
                    series: series,
                    onTap: () => context.push('/series/${series.metadata.slug}'),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
