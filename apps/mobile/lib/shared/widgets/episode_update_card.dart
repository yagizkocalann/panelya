import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../core/contracts/generated/generated.dart';
import 'cover_image.dart';

/// "Yeni Eklenen Bölümler" akışındaki tek satır (bkz. web `update-card`,
/// `app/new-episodes/page.tsx`): küçük bir kapak + yayın tarihi + seri
/// adı/bölüm numarası + bölüm başlığı/okuma süresi. Satırın tamamı bölümü
/// açar (birincil aksiyon, web'deki "Bölümü Oku" karşılığı); ayrı bir
/// "Seriyi incele" bağlantısı seri detayına gider (web'deki ikincil "Seriyi
/// İncele" aksiyonu) — görünen her aksiyon çalışır (ADR-010).
class EpisodeUpdateCard extends StatelessWidget {
  const EpisodeUpdateCard({
    super.key,
    required this.series,
    required this.episode,
    required this.onOpenEpisode,
    required this.onOpenSeries,
  });

  final DiscoverySeriesSummary series;
  final EpisodeSummary episode;
  final VoidCallback onOpenEpisode;
  final VoidCallback onOpenSeries;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Semantics(
      button: true,
      label:
          '${series.title}, Bölüm ${episode.number}: ${episode.title}. '
          '${episode.publishedAt}. ${episode.readTime}.',
      child: Material(
        color: tokens.colors.surface2,
        borderRadius: BorderRadius.circular(tokens.radii.md),
        child: InkWell(
          onTap: onOpenEpisode,
          borderRadius: BorderRadius.circular(tokens.radii.md),
          child: Container(
            constraints: BoxConstraints(minHeight: tokens.sizes.minTouchTarget),
            padding: EdgeInsets.all(tokens.spacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radii.md),
              border: Border.all(color: tokens.colors.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radii.sm),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: CoverImage(
                      src: series.coverImage,
                      position: series.coverPosition,
                      semanticLabel: series.title,
                      tone: series.tone,
                      variants: series.coverImageVariants,
                    ),
                  ),
                ),
                SizedBox(width: tokens.spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        episode.publishedAt,
                        style: tokens.typography.bodySmall.copyWith(
                          color: tokens.colors.mint,
                        ),
                      ),
                      SizedBox(height: tokens.spacing.xs / 2),
                      Text(
                        '${series.title} · Bölüm ${episode.number}',
                        style: tokens.typography.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: tokens.spacing.xs / 2),
                      Text(
                        '${episode.title} · ${episode.readTime}',
                        style: tokens.typography.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: tokens.spacing.xs),
                      _InlineSeriesLink(
                        tokens: tokens,
                        onTap: onOpenSeries,
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

/// "Seriyi incele" ikincil aksiyonu. Ebeveyn kartın `InkWell`'inin (bölümü
/// açan) İÇİNDE ayrı bir dokunma hedefi kurar; Flutter'ın gesture arena'sı
/// en içteki `InkWell`'i önceliklendirdiği için bu bağlantıya dokunmak
/// bölümü değil seriyi açar.
class _InlineSeriesLink extends StatelessWidget {
  const _InlineSeriesLink({required this.tokens, required this.onTap});

  final AppTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Seriyi incele',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radii.sm),
          child: Container(
            constraints: BoxConstraints(minHeight: tokens.sizes.minTouchTarget),
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.xs),
            child: Text(
              'Seriyi incele',
              style: tokens.typography.label.copyWith(color: tokens.colors.mint),
            ),
          ),
        ),
      ),
    );
  }
}
