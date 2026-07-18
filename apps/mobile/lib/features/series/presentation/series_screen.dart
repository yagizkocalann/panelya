import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_error_presenter.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/contracts/episode_contract.dart';
import '../../../core/contracts/series_detail_response.dart';
import '../../../shared/widgets/state_views.dart';
import 'series_providers.dart';

/// Seri detay ekranı (`/series/:slug`): `GET /api/series/:slug`'dan gelen
/// meta veriyi ve bölüm listesini gösterir. Faz 1'de basit bir liste/detay
/// taslağı; kapak görseli, yorum/puan ve favori Faz 2'nin işidir.
class SeriesScreen extends ConsumerWidget {
  const SeriesScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(seriesDetailProvider(slug));

    return Scaffold(
      appBar: AppBar(title: const Text('Seri')),
      body: SafeArea(
        child: detail.when(
          loading: () => const AppLoadingView(label: 'Seri yükleniyor'),
          error: (error, stackTrace) => AppErrorView(
            message: error is ApiException
                ? describeApiException(error)
                : 'Beklenmeyen bir hata oluştu.',
            onRetry: () => ref.invalidate(seriesDetailProvider(slug)),
          ),
          data: (response) => _SeriesDetailView(seriesSlug: slug, response: response),
        ),
      ),
    );
  }
}

class _SeriesDetailView extends StatelessWidget {
  const _SeriesDetailView({required this.seriesSlug, required this.response});

  final String seriesSlug;
  final SeriesDetailResponse response;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final metadata = response.series;
    final episodes = response.episodes;

    if (episodes.isEmpty) {
      return const AppEmptyView(message: 'Bu serinin henüz yayınlanmış bölümü yok.');
    }

    // Bölümler sunucudan en yeniden en eskiye sıralı gelir (bkz.
    // core/contracts/series_detail_response.dart); ilk öğe "devam et/başla"
    // için en güncel bölümdür.
    final latestEpisode = episodes.first;

    return ListView(
      padding: EdgeInsets.all(tokens.spacing.md),
      children: [
        Text(metadata.eyebrow, style: tokens.typography.bodySmall.copyWith(color: tokens.colors.mint)),
        SizedBox(height: tokens.spacing.xs),
        Text(metadata.title, style: tokens.typography.displayLarge),
        SizedBox(height: tokens.spacing.sm),
        Wrap(
          spacing: tokens.spacing.xs,
          runSpacing: tokens.spacing.xs,
          children: [
            _Tag(text: metadata.status),
            for (final genre in metadata.genres) _Tag(text: genre),
          ],
        ),
        SizedBox(height: tokens.spacing.md),
        Text(metadata.longDescription, style: tokens.typography.bodyLarge),
        SizedBox(height: tokens.spacing.lg),
        SizedBox(
          height: tokens.sizes.minTouchTarget,
          child: FilledButton(
            onPressed: () => context.push(
              '/series/$seriesSlug/read/${latestEpisode.slug}',
            ),
            child: Text('Okumaya başla · Bölüm ${latestEpisode.number}'),
          ),
        ),
        SizedBox(height: tokens.spacing.lg),
        Text('Bölümler', style: tokens.typography.titleMedium),
        SizedBox(height: tokens.spacing.sm),
        for (final episode in episodes)
          _EpisodeTile(
            episode: episode,
            onTap: () => context.push(
              '/series/$seriesSlug/read/${episode.slug}',
            ),
          ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.sm, vertical: tokens.spacing.xs / 2),
      decoration: BoxDecoration(
        color: tokens.colors.surface3,
        borderRadius: BorderRadius.circular(tokens.radii.pill),
      ),
      child: Text(text, style: tokens.typography.bodySmall),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({required this.episode, required this.onTap});

  final EpisodeSummaryContract episode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      button: true,
      label: 'Bölüm ${episode.number}: ${episode.title}. ${episode.readTime}.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radii.md),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: tokens.sizes.minTouchTarget),
          child: Container(
            margin: EdgeInsets.only(bottom: tokens.spacing.sm),
            padding: EdgeInsets.all(tokens.spacing.md),
            decoration: BoxDecoration(
              color: tokens.colors.surface2,
              borderRadius: BorderRadius.circular(tokens.radii.md),
              border: Border.all(color: tokens.colors.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bölüm ${episode.number} · ${episode.title}',
                        style: tokens.typography.titleMedium,
                      ),
                      SizedBox(height: tokens.spacing.xs),
                      Text(
                        '${episode.publishedAt} · ${episode.readTime} · ${episode.panelCount} panel',
                        style: tokens.typography.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: tokens.colors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
