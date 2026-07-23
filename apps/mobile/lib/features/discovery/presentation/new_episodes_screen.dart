import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_error_presenter.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/episode_update_card.dart';
import '../../../shared/widgets/state_views.dart';
import 'discovery_providers.dart';

/// `/new-episodes` — ana sayfadaki "Yeni Eklenen Bölümler" bölümünün 4-kart
/// kısıtı OLMADAN tam listesi (bkz. PLAN Görev 6).
/// `discoveryResponse.latestEpisodes` sırası API'den geldiği gibi korunur
/// (sunucunun gerçek yayın sırası, bkz. ADR-044); `episode.publishedAt`
/// yalnız ekranda gösterilecek yerelleştirilmiş bir etikettir, istemci onu
/// bir sıralama anahtarı olarak KULLANMAZ/yeniden sıralamaz (bkz.
/// docs/mobile-handoff.md madde 6).
class NewEpisodesScreen extends ConsumerWidget {
  const NewEpisodesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discovery = ref.watch(discoveryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Eklenen Bölümler')),
      body: SafeArea(
        child: discovery.when(
          loading: () =>
              const AppLoadingView(label: 'Yeni bölümler yükleniyor'),
          error: (error, stackTrace) => AppErrorView(
            message: error is ApiException
                ? describeApiException(error)
                : 'Beklenmeyen bir hata oluştu.',
            onRetry: () => ref.invalidate(discoveryProvider),
          ),
          data: (response) {
            final updates = response.latestEpisodes;
            if (updates.isEmpty) {
              return const AppEmptyView(
                message: 'Henüz yayınlanmış bir bölüm yok.',
              );
            }

            final tokens = context.tokens;

            return RefreshIndicator(
              onRefresh: () => ref.refresh(discoveryProvider.future),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(tokens.spacing.md),
                itemCount: updates.length,
                separatorBuilder: (context, index) =>
                    SizedBox(height: tokens.spacing.sm),
                itemBuilder: (context, index) {
                  final update = updates[index];
                  return EpisodeUpdateCard(
                    key: ValueKey(
                      'episode-update-${update.series.slug}-${update.episode.slug}',
                    ),
                    series: update.series,
                    episode: update.episode,
                    onOpenEpisode: () => context.push(
                      '/series/${update.series.slug}/read/${update.episode.slug}',
                    ),
                    onOpenSeries: () =>
                        context.push('/series/${update.series.slug}'),
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
