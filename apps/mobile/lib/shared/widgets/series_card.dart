import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../core/contracts/generated/generated.dart';
import 'cover_image.dart';

/// [SeriesCard]'ın render etmek için ihtiyaç duyduğu alanların düz
/// (flattened), DTO-bağımsız bir görünümü.
///
/// `packages/contracts/schema.json`'dan üretilen `SeriesSummary` (tam
/// katalog, bkz. `GET /api/catalog`) ve `DiscoverySeriesSummary` (editorial
/// keşif akışı, bkz. `GET /api/discovery`) neredeyse aynı alanları taşıyan
/// FARKLI DTO sınıflarıdır (ikisi de aynı JSON Schema `$defs` şeklini
/// paylaşır ama codegen ayrı tipler üretir). [SeriesCard] widget'ının bu iki
/// tipi ayrı ayrı bilmesi (veya kopyalanmış iki kart widget'ı) yerine, her
/// iki DTO'dan da türetilebilen bu küçük value tipi tek bir kart
/// implementasyonunun her yerde (ana sayfa, `/catalog`, `/new-series`)
/// yeniden kullanılmasını sağlar.
class SeriesCardData {
  const SeriesCardData({
    required this.slug,
    required this.title,
    required this.eyebrow,
    required this.status,
    required this.genres,
    required this.tone,
    required this.rating,
    required this.episodeCount,
    this.isNew,
    this.coverImage,
    this.coverImageVariants,
    this.coverPosition,
  });

  /// Tam katalog (`GET /api/catalog`) girdisinden.
  factory SeriesCardData.fromSeriesSummary(SeriesSummary series) {
    return SeriesCardData(
      slug: series.slug,
      title: series.title,
      eyebrow: series.eyebrow,
      status: series.status,
      genres: series.genres,
      tone: series.tone,
      rating: series.rating,
      episodeCount: series.episodeCount,
      isNew: series.isNew,
      coverImage: series.coverImage,
      coverImageVariants: series.coverImageVariants,
      coverPosition: series.coverPosition,
    );
  }

  /// Editorial keşif akışı (`GET /api/discovery`) girdisinden.
  factory SeriesCardData.fromDiscoverySeriesSummary(
    DiscoverySeriesSummary series,
  ) {
    return SeriesCardData(
      slug: series.slug,
      title: series.title,
      eyebrow: series.eyebrow,
      status: series.status,
      genres: series.genres,
      tone: series.tone,
      rating: series.rating,
      episodeCount: series.episodeCount,
      isNew: series.isNew,
      coverImage: series.coverImage,
      coverImageVariants: series.coverImageVariants,
      coverPosition: series.coverPosition,
    );
  }

  final String slug;
  final String title;
  final String eyebrow;
  final String status;
  final List<String> genres;
  final PanelTone tone;
  final double rating;
  final int episodeCount;
  final bool? isNew;
  final String? coverImage;
  final List<PublicMediaVariant>? coverImageVariants;
  final String? coverPosition;
}

/// Keşif ızgarasında bir seriyi özetleyen poster kart (Faz 2): 3:4 kapak
/// oranı, başlık ve tür/durum bilgisiyle keskin bir bilgi hiyerarşisi
/// kurar (bkz. production-bible.md §7 — "Kartlar keskin bilgi
/// hiyerarşisine, posterler 3:4 orana sahiptir").
///
/// [series] DTO-bağımsız [SeriesCardData]'dır (bkz. o sınıfın doc yorumu);
/// çağıran taraf `SeriesSummary.fromSeriesSummary`/`.fromDiscoverySeriesSummary`
/// ile üretir.
class SeriesCard extends StatelessWidget {
  const SeriesCard({super.key, required this.series, required this.onTap});

  final SeriesCardData series;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final primaryGenre = series.genres.isNotEmpty ? series.genres.first : null;

    return Semantics(
      button: true,
      label: '${series.title}. ${series.eyebrow}. ${series.status}. '
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
                        src: series.coverImage,
                        position: series.coverPosition,
                        semanticLabel: series.title,
                        tone: series.tone,
                        variants: series.coverImageVariants,
                      ),
                    ),
                    if (series.isNew == true)
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
                series.title,
                style: tokens.typography.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: tokens.spacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      series.status,
                      style: tokens.typography.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.star_rounded, size: 14, color: tokens.colors.mint),
                  SizedBox(width: tokens.spacing.xs / 2),
                  Text(
                    series.rating.toStringAsFixed(1),
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
