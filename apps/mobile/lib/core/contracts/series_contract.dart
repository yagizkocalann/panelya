// GEÇİCİ ADAPTER: packages/contracts main'e gelince bu dosya ortak sözleşmeyle
// değiştirilecek (bkz. docs/mobile-handoff.md Ortaklık kuralları #3).
//
// Kaynak: `app/data/catalog.ts` (`Series` tipi, `episodes` alanı hariç) ve
// bu tipin `app/api/catalog/route.ts` / `app/api/series/[slug]/route.ts`
// route handler'larında dönüştürülme biçimleri.

import 'package:flutter/foundation.dart';

import 'episode_contract.dart';

/// Ortak seri alanları. Hem `GET /api/series/:slug` cevabındaki `series`
/// alanının hem de `GET /api/catalog` cevabındaki her kart girdisinin
/// (episodeCount/latestEpisode hariç) taşıdığı alan kümesidir.
///
/// `status` sunucuda `"Devam Ediyor" | "Tamamlandı"`; `tone` ise
/// `story_panel.dart`'taki `PanelTone` ile aynı kapalı kümedir ama seri
/// düzeyinde ayrı bir alan olduğu için burada ham string tutulur (rota,
/// tone'u panel gibi değil düz string olarak döner).
@immutable
class SeriesMetadataContract {
  const SeriesMetadataContract({
    required this.slug,
    required this.title,
    required this.eyebrow,
    required this.creator,
    required this.description,
    required this.longDescription,
    required this.status,
    required this.genres,
    required this.tone,
    required this.updatedAt,
    required this.rating,
    required this.followers,
    this.isNew,
    this.coverImage,
    this.coverPosition,
  });

  factory SeriesMetadataContract.fromJson(Map<String, dynamic> json) {
    return SeriesMetadataContract(
      slug: json['slug'] as String,
      title: json['title'] as String,
      eyebrow: json['eyebrow'] as String,
      creator: json['creator'] as String,
      description: json['description'] as String,
      longDescription: json['longDescription'] as String,
      status: json['status'] as String,
      genres: (json['genres'] as List<dynamic>).cast<String>(),
      tone: json['tone'] as String,
      updatedAt: json['updatedAt'] as String,
      rating: (json['rating'] as num).toDouble(),
      followers: json['followers'] as String,
      isNew: json['isNew'] as bool?,
      coverImage: json['coverImage'] as String?,
      coverPosition: json['coverPosition'] as String?,
    );
  }

  final String slug;
  final String title;
  final String eyebrow;
  final String creator;
  final String description;
  final String longDescription;

  /// `"Devam Ediyor" | "Tamamlandı"`.
  final String status;
  final List<String> genres;

  /// `PanelTone` ile aynı kapalı küme (ham string olarak tutulur).
  final String tone;

  /// Sunucuda okunabilir bir etikettir ("Bugün", "3 gün önce"), ISO tarih
  /// değildir.
  final String updatedAt;
  final double rating;
  final String followers;
  final bool? isNew;
  final String? coverImage;
  final String? coverPosition;

  bool get isCompleted => status == 'Tamamlandı';
}

/// `GET /api/catalog` cevabındaki `series[]` girdisi:
/// `{ ...series, episodeCount, latestEpisode }`
/// (bkz. route handler: `seriesCatalog.map(({ episodes, ...series }) => ({ ...series, episodeCount: episodes.length, latestEpisode: episodes[0] }))`).
@immutable
class SeriesSummaryContract {
  const SeriesSummaryContract({
    required this.metadata,
    required this.episodeCount,
    required this.latestEpisode,
  });

  factory SeriesSummaryContract.fromJson(Map<String, dynamic> json) {
    return SeriesSummaryContract(
      metadata: SeriesMetadataContract.fromJson(json),
      episodeCount: (json['episodeCount'] as num).toInt(),
      latestEpisode: json['latestEpisode'] == null
          ? null
          : EpisodeContract.fromJson(
              json['latestEpisode'] as Map<String, dynamic>,
            ),
    );
  }

  final SeriesMetadataContract metadata;
  final int episodeCount;

  /// Yayınlanmış seri en az bir bölüm içerdiği için pratikte her zaman
  /// dolu gelir; yine de sunucu tarafı boş katalog döndürürse (örn. filtre
  /// sonucu) `null` olabileceğinden nullable tutulur.
  final EpisodeContract? latestEpisode;
}
