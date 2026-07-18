import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../core/contracts/series_contract.dart';

/// Katalog listesinde bir seriyi özetleyen kart. Faz 1 iskeleti: kapak
/// görseli yerine baş harf rozeti kullanır (gerçek kapak/poster görseli
/// Faz 2'nin işi); tipografi ve renkler yalnız [AppTokens] üzerinden gelir.
class SeriesCard extends StatelessWidget {
  const SeriesCard({super.key, required this.series, required this.onTap});

  final SeriesSummaryContract series;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final metadata = series.metadata;

    return Semantics(
      button: true,
      label: '${metadata.title}. ${metadata.status}. '
          '${series.episodeCount} bölüm.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radii.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: tokens.sizes.minTouchTarget,
          ),
          child: Container(
            padding: EdgeInsets.all(tokens.spacing.md),
            decoration: BoxDecoration(
              color: tokens.colors.surface2,
              borderRadius: BorderRadius.circular(tokens.radii.lg),
              border: Border.all(color: tokens.colors.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CoverPlaceholder(title: metadata.title, tokens: tokens),
                SizedBox(width: tokens.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metadata.eyebrow,
                        style: tokens.typography.bodySmall.copyWith(
                          color: tokens.colors.mint,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: tokens.spacing.xs),
                      Text(
                        metadata.title,
                        style: tokens.typography.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: tokens.spacing.xs),
                      Text(
                        metadata.description,
                        style: tokens.typography.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: tokens.spacing.sm),
                      Wrap(
                        spacing: tokens.spacing.xs,
                        runSpacing: tokens.spacing.xs,
                        children: [
                          _Chip(text: metadata.status, tokens: tokens),
                          _Chip(
                            text: '${series.episodeCount} bölüm',
                            tokens: tokens,
                          ),
                          if (metadata.isNew == true)
                            _Chip(
                              text: 'Yeni',
                              tokens: tokens,
                              highlight: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.title, required this.tokens});

  final String title;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    final initial = title.trim().isEmpty ? '?' : title.trim()[0].toUpperCase();
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.colors.surface3,
        borderRadius: BorderRadius.circular(tokens.radii.md),
      ),
      child: Text(
        initial,
        style: tokens.typography.titleLarge.copyWith(color: tokens.colors.mint),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.tokens, this.highlight = false});

  final String text;
  final AppTokens tokens;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.sm,
        vertical: tokens.spacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: highlight ? tokens.colors.mint : tokens.colors.surface3,
        borderRadius: BorderRadius.circular(tokens.radii.pill),
      ),
      child: Text(
        text,
        style: tokens.typography.bodySmall.copyWith(
          color: highlight ? tokens.colors.background : tokens.colors.muted,
        ),
      ),
    );
  }
}
