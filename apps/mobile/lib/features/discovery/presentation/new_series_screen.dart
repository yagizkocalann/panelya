import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_error_presenter.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/home_button.dart';
import '../../../shared/widgets/series_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../discover/presentation/discover_screen.dart'
    show discoverGridColumnsForWidth, seriesCardMainAxisExtent;
import 'discovery_providers.dart';

/// `/new-series` — ana sayfadaki "Yeni Seriler" bölümünün 4-kart kısıtı
/// OLMADAN tam listesi (bkz. PLAN Görev 6). `discoveryResponse.newSeries`
/// sırası API'den geldiği gibi korunur; istemci 30 günlük "yeni seri"
/// penceresini veya `isNew` değerini cihaz saatinden yeniden HESAPLAMAZ
/// (bkz. docs/mobile-handoff.md madde 5) — sunucunun zaten uyguladığı kural
/// ve sıra aynen görüntülenir.
class NewSeriesScreen extends ConsumerWidget {
  const NewSeriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discovery = ref.watch(discoveryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Seriler'),
        actions: const [HomeButton()],
      ),
      body: SafeArea(
        child: discovery.when(
          loading: () => const AppLoadingView(label: 'Yeni seriler yükleniyor'),
          error: (error, stackTrace) => AppErrorView(
            message: error is ApiException
                ? describeApiException(error)
                : 'Beklenmeyen bir hata oluştu.',
            onRetry: () => ref.invalidate(discoveryProvider),
          ),
          data: (response) {
            final newSeries = response.newSeries;
            if (newSeries.isEmpty) {
              return const AppEmptyView(
                message: 'Şu anda yeni bir seri yok.',
              );
            }

            final tokens = context.tokens;
            final width = MediaQuery.sizeOf(context).width;
            final columns = discoverGridColumnsForWidth(width);
            final gridContentWidth = width - tokens.spacing.md * 2;
            final columnWidth =
                (gridContentWidth - (columns - 1) * tokens.spacing.md) /
                columns;
            final mainAxisExtent = seriesCardMainAxisExtent(
              context,
              columnWidth,
            );

            return RefreshIndicator(
              onRefresh: () => ref.refresh(discoveryProvider.future),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.all(tokens.spacing.md),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: tokens.spacing.md,
                        crossAxisSpacing: tokens.spacing.md,
                        mainAxisExtent: mainAxisExtent,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final series = newSeries[index];
                        return SeriesCard(
                          key: ValueKey('series-card-${series.slug}'),
                          series: SeriesCardData.fromDiscoverySeriesSummary(
                            series,
                          ),
                          onTap: () => context.push('/series/${series.slug}'),
                        );
                      }, childCount: newSeries.length),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
