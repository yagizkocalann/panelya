import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_error_presenter.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/contracts/generated/generated.dart';
import '../../../features/progress/domain/reading_progress.dart';
import '../../../features/progress/presentation/reading_progress_providers.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../../shared/widgets/state_views.dart';
import 'series_providers.dart';

/// Seri detay ekranı (`/series/:slug`): `GET /api/series/:slug`'dan gelen
/// kapak, meta veri ve bölüm listesini gösterir (bkz. PLAN Görev 3 ve
/// production-bible.md §7).
class SeriesScreen extends ConsumerWidget {
  const SeriesScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(seriesDetailProvider(slug));

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.asData?.value.series.title ?? 'Seri'),
      ),
      body: SafeArea(
        child: detail.when(
          loading: () => const AppLoadingView(label: 'Seri yükleniyor'),
          error: (error, stackTrace) => AppErrorView(
            message: error is ApiException
                ? describeApiException(error)
                : 'Beklenmeyen bir hata oluştu.',
            onRetry: () => ref.invalidate(seriesDetailProvider(slug)),
          ),
          data: (response) =>
              _SeriesDetailView(seriesSlug: slug, response: response),
        ),
      ),
    );
  }
}

/// Bölümler arasında görünen numaraya (sequence etiketine) göre en küçük
/// olanı bulur. Sunucu bölümleri yeni-en eski sıralı döndürür (bkz.
/// `lib/core/contracts/generated/series_detail_response.dart`), ama
/// "Okumaya başla" ilk bölüme (en düşük numaraya) götürmelidir (bkz. PLAN
/// Görev 3); bu yüzden sıralamaya güvenmek yerine açıkça en küçük
/// `number`'ı arar.
EpisodeSummary firstEpisodeOf(List<EpisodeSummary> episodes) {
  return episodes.reduce((a, b) => a.number <= b.number ? a : b);
}

class _SeriesDetailView extends ConsumerWidget {
  const _SeriesDetailView({required this.seriesSlug, required this.response});

  final String seriesSlug;
  final SeriesDetailResponse response;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final metadata = response.series;
    final episodes = response.episodes;

    if (episodes.isEmpty) {
      return const AppEmptyView(
        message: 'Bu serinin henüz yayınlanmış bölümü yok.',
      );
    }

    final firstEpisode = firstEpisodeOf(episodes);
    // Cihaz-yerel "kaldığın yerden devam et" kaydı (bkz. PLAN, hesapsız
    // özellik — auth'lu `/api/progress` ile ilgisi yok). Kayıt yoksa
    // mevcut "Okumaya başla" davranışı değişmeden kalır.
    final progress = ref.watch(readingProgressForSeriesProvider(seriesSlug));

    return ListView(
      padding: EdgeInsets.all(tokens.spacing.md),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radii.lg),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: CoverImage(
              src: metadata.coverImage,
              position: metadata.coverPosition,
              semanticLabel: metadata.title,
              tone: metadata.tone,
            ),
          ),
        ),
        SizedBox(height: tokens.spacing.md),
        Text(
          metadata.eyebrow,
          style: tokens.typography.bodySmall.copyWith(color: tokens.colors.mint),
        ),
        SizedBox(height: tokens.spacing.xs),
        Text(metadata.title, style: tokens.typography.displayLarge),
        SizedBox(height: tokens.spacing.xs),
        Semantics(
          label: 'Yaratıcı: ${metadata.creator}',
          child: Text(
            metadata.creator,
            style: tokens.typography.bodyMedium,
          ),
        ),
        SizedBox(height: tokens.spacing.sm),
        Semantics(
          label:
              '${metadata.rating.toStringAsFixed(1)} üzerinden puan, '
              '${metadata.followers} takipçi, ${episodes.length} bölüm.',
          child: Wrap(
            spacing: tokens.spacing.md,
            runSpacing: tokens.spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, size: 16, color: tokens.colors.mint),
                  SizedBox(width: tokens.spacing.xs / 2),
                  Text(metadata.rating.toStringAsFixed(1), style: tokens.typography.bodyMedium),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_alt_outlined, size: 16, color: tokens.colors.muted),
                  SizedBox(width: tokens.spacing.xs / 2),
                  Text('${metadata.followers} takipçi', style: tokens.typography.bodyMedium),
                ],
              ),
              Text('${episodes.length} bölüm', style: tokens.typography.bodyMedium),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.md),
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
        _StartReadingActions(
          seriesSlug: seriesSlug,
          firstEpisode: firstEpisode,
          progress: progress,
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

/// Seri detayının birincil okuma aksiyonu.
///
/// Cihaz-yerel ilerleme kaydı [progress] `null` ise (kullanıcı bu seride
/// hiç bölüm açmamış) mevcut tek "Okumaya başla" davranışı değişmeden
/// kalır. Kayıt varsa birincil aksiyon "Devam et: Bölüm N" olur ve
/// kaydedilen bölüme götürür; yanında daha küçük bir ikincil "Baştan
/// başla" aksiyonu her zaman ilk bölüme döner (PLAN — hesapsız, cihaz-yerel
/// "kaldığın yerden devam et").
class _StartReadingActions extends StatelessWidget {
  const _StartReadingActions({
    required this.seriesSlug,
    required this.firstEpisode,
    required this.progress,
  });

  final String seriesSlug;
  final EpisodeSummary firstEpisode;
  final ReadingProgress? progress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    if (progress == null) {
      return SizedBox(
        height: tokens.sizes.minTouchTarget,
        child: FilledButton(
          onPressed: () => context.push(
            '/series/$seriesSlug/read/${firstEpisode.slug}',
          ),
          child: Text('Okumaya başla · Bölüm ${firstEpisode.number}'),
        ),
      );
    }

    // `FilledButton`/`OutlinedButton` her biri kendi `button: true` +
    // metin-tabanlı semantics etiketini zaten üretir (bkz. codebase
    // genelindeki diğer butonlar — "Okumaya başla", "Seriyi incele" vb.);
    // ek bir dış `Semantics` sarmalayıcı gereksiz, iç içe iki düğüm
    // oluşturup ekran okuyucuda yinelemeye yol açardı. Bu iki aksiyon zaten
    // ayrı `SizedBox`/buton olduğundan ayrı ayrı erişilebilirler.
    final continueLabel = 'Devam et: Bölüm ${progress!.episodeNumber}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: tokens.sizes.minTouchTarget,
          child: FilledButton(
            onPressed: () => context.push(
              '/series/$seriesSlug/read/${progress!.episodeSlug}',
            ),
            child: Text(continueLabel),
          ),
        ),
        SizedBox(height: tokens.spacing.sm),
        SizedBox(
          height: tokens.sizes.minTouchTarget,
          child: OutlinedButton(
            onPressed: () => context.push(
              '/series/$seriesSlug/read/${firstEpisode.slug}',
            ),
            child: const Text('Baştan başla'),
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

  final EpisodeSummary episode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      button: true,
      label: 'Bölüm ${episode.number}: ${episode.title}. ${episode.publishedAt}. ${episode.readTime}.',
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
                _SequenceBadge(number: episode.number, tokens: tokens),
                SizedBox(width: tokens.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episode.title,
                        style: tokens.typography.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: tokens.spacing.xs),
                      Text(
                        '${episode.publishedAt} · ${episode.readTime} · ${episode.panelCount} panel',
                        style: tokens.typography.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

/// Bölümün görünür sıra etiketi ("Bölüm N"'in rozet biçimi).
class _SequenceBadge extends StatelessWidget {
  const _SequenceBadge({required this.number, required this.tokens});

  final int number;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    final size = tokens.spacing.xl + tokens.spacing.sm;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.colors.surface3,
        borderRadius: BorderRadius.circular(tokens.radii.md),
      ),
      child: Text(
        '$number',
        style: tokens.typography.titleMedium.copyWith(color: tokens.colors.mint),
      ),
    );
  }
}
