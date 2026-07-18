// GEÇİCİ ADAPTER: packages/contracts main'e gelince bu dosya ortak sözleşmeyle
// değiştirilecek (bkz. docs/mobile-handoff.md Ortaklık kuralları #3).
//
// Kaynak: `app/data/catalog.ts` (`Episode` tipi) ve bu tipin
// `app/api/catalog/route.ts`, `app/api/series/[slug]/route.ts`,
// `app/api/series/[slug]/episodes/[episode]/route.ts` route handler'larında
// dönüştürülme biçimleri.

import 'package:flutter/foundation.dart';

import 'story_panel.dart';

/// Tam bölüm: `GET /api/series/:slug/episodes/:episodeSlug` cevabındaki
/// `episode` alanı ve `GET /api/catalog` cevabındaki her seri kartının
/// `latestEpisode` alanı bu şekli kullanır (panels dahil, tam Episode).
@immutable
class EpisodeContract {
  const EpisodeContract({
    required this.slug,
    required this.number,
    required this.title,
    required this.publishedAt,
    required this.readTime,
    required this.panels,
  });

  factory EpisodeContract.fromJson(Map<String, dynamic> json) {
    return EpisodeContract(
      slug: json['slug'] as String,
      number: (json['number'] as num).toInt(),
      title: json['title'] as String,
      publishedAt: json['publishedAt'] as String,
      readTime: json['readTime'] as String,
      panels: (json['panels'] as List<dynamic>)
          .map((panel) => StoryPanel.fromJson(panel as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final String slug;
  final int number;
  final String title;

  /// Sunucuda okunabilir bir etikettir ("18 Temmuz 2026"), ISO tarih değildir.
  final String publishedAt;
  final String readTime;
  final List<StoryPanel> panels;
}

/// `GET /api/series/:slug` cevabındaki `episodes[]` şekli:
/// `{ ...episode, panelCount }` içinde `panels` alanı düşürülüp yerine
/// `panelCount` konur (bkz. route handler: `episodes.map(({panels, ...episode}) => ({...episode, panelCount: panels.length}))`).
@immutable
class EpisodeSummaryContract {
  const EpisodeSummaryContract({
    required this.slug,
    required this.number,
    required this.title,
    required this.publishedAt,
    required this.readTime,
    required this.panelCount,
  });

  factory EpisodeSummaryContract.fromJson(Map<String, dynamic> json) {
    return EpisodeSummaryContract(
      slug: json['slug'] as String,
      number: (json['number'] as num).toInt(),
      title: json['title'] as String,
      publishedAt: json['publishedAt'] as String,
      readTime: json['readTime'] as String,
      panelCount: (json['panelCount'] as num).toInt(),
    );
  }

  final String slug;
  final int number;
  final String title;
  final String publishedAt;
  final String readTime;
  final int panelCount;
}

/// `GET /api/series/:slug/episodes/:episodeSlug` cevabındaki
/// `navigation.previous` / `navigation.next` şekli: `{ slug, number } | null`.
@immutable
class EpisodeNavRef {
  const EpisodeNavRef({required this.slug, required this.number});

  factory EpisodeNavRef.fromJson(Map<String, dynamic> json) {
    return EpisodeNavRef(
      slug: json['slug'] as String,
      number: (json['number'] as num).toInt(),
    );
  }

  final String slug;
  final int number;
}
