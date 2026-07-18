// GEÇİCİ ADAPTER: packages/contracts main'e gelince bu dosya ortak sözleşmeyle
// değiştirilecek (bkz. docs/mobile-handoff.md Ortaklık kuralları #3).
//
// Kaynak: `app/api/series/[slug]/episodes/[episode]/route.ts`.
//
// ```ts
// return Response.json({
//   schemaVersion: "1.0",
//   series: { slug: series.slug, title: series.title },
//   episode, // tam Episode (panels dahil)
//   navigation: {
//     previous: adjacent.previous ? { slug, number } : null,
//     next: adjacent.next ? { slug, number } : null,
//   },
// });
// ```
//
// Seri veya bölüm bulunamazsa route `404` ile
// `{ "error": "episode_not_found" }` döner; bu durum `ApiException`
// (bkz. lib/core/api) tarafında ele alınır, burada modellenmez.

import 'package:flutter/foundation.dart';

import 'episode_contract.dart';
import 'schema_version.dart';

/// `navigation.previous` / `navigation.next` gövdesindeki üst seviye
/// `series` alanı: yalnız `slug` ve `title` içerir, tam
/// [SeriesMetadataContract] değildir.
@immutable
class EpisodeManifestSeriesRef {
  const EpisodeManifestSeriesRef({required this.slug, required this.title});

  factory EpisodeManifestSeriesRef.fromJson(Map<String, dynamic> json) {
    return EpisodeManifestSeriesRef(
      slug: json['slug'] as String,
      title: json['title'] as String,
    );
  }

  final String slug;
  final String title;
}

/// `GET /api/series/:slug/episodes/:episodeSlug` cevabının tam gövdesi
/// (200 durumunda) — okuyucu manifesti.
@immutable
class EpisodeManifestResponse {
  const EpisodeManifestResponse({
    required this.schemaVersion,
    required this.series,
    required this.episode,
    required this.previous,
    required this.next,
  });

  factory EpisodeManifestResponse.fromJson(Map<String, dynamic> json) {
    assertSupportedSchemaVersion(json);
    final navigation = json['navigation'] as Map<String, dynamic>;
    return EpisodeManifestResponse(
      schemaVersion: json['schemaVersion'] as String,
      series: EpisodeManifestSeriesRef.fromJson(
        json['series'] as Map<String, dynamic>,
      ),
      episode: EpisodeContract.fromJson(json['episode'] as Map<String, dynamic>),
      previous: navigation['previous'] == null
          ? null
          : EpisodeNavRef.fromJson(
              navigation['previous'] as Map<String, dynamic>,
            ),
      next: navigation['next'] == null
          ? null
          : EpisodeNavRef.fromJson(navigation['next'] as Map<String, dynamic>),
    );
  }

  final String schemaVersion;
  final EpisodeManifestSeriesRef series;
  final EpisodeContract episode;
  final EpisodeNavRef? previous;
  final EpisodeNavRef? next;
}
