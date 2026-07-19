import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../core/contracts/series_contract.dart';
import 'cover_image.dart';

/// Keşif ızgarasında bir seriyi özetleyen poster kart (Faz 2): 3:4 kapak
/// oranı, başlık ve tür/durum bilgisiyle keskin bir bilgi hiyerarşisi
/// kurar (bkz. production-bible.md §7 — "Kartlar keskin bilgi
/// hiyerarşisine, posterler 3:4 orana sahiptir").
class SeriesCard extends StatelessWidget {
  const SeriesCard({super.key, required this.series, required this.onTap});

  final SeriesSummaryContract series;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final metadata = series.metadata;
    final primaryGenre = metadata.genres.isNotEmpty ? metadata.genres.first : null;

    return Semantics(
      button: true,
      label: '${metadata.title}. ${metadata.eyebrow}. ${metadata.status}. '
          '${series.episodeCount} bölüm.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radii.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: tokens.sizes.minTouchTarget),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 3 / 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(tokens.radii.lg),
                      child: CoverImage(
                        src: metadata.coverImage,
                        position: metadata.coverPosition,
                        semanticLabel: metadata.title,
                      ),
                    ),
                    if (metadata.isNew == true)
                      Positioned(
                        top: tokens.spacing.sm,
                        right: tokens.spacing.sm,
                        child: _Chip(text: 'Yeni', tokens: tokens, highlight: true),
                      ),
                  ],
                ),
              ),
              SizedBox(height: tokens.spacing.sm),
              if (primaryGenre != null)
                Text(
                  primaryGenre,
                  style: tokens.typography.bodySmall.copyWith(color: tokens.colors.mint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              SizedBox(height: tokens.spacing.xs),
              Text(
                metadata.title,
                style: tokens.typography.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: tokens.spacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      metadata.status,
                      style: tokens.typography.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.star_rounded, size: 14, color: tokens.colors.mint),
                  SizedBox(width: tokens.spacing.xs / 2),
                  Text(
                    metadata.rating.toStringAsFixed(1),
                    style: tokens.typography.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
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
