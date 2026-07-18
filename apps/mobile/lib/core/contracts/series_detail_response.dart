// GEÇİCİ ADAPTER: packages/contracts main'e gelince bu dosya ortak sözleşmeyle
// değiştirilecek (bkz. docs/mobile-handoff.md Ortaklık kuralları #3).
//
// Kaynak: `app/api/series/[slug]/route.ts`.
//
// ```ts
// return Response.json({
//   schemaVersion: "1.0",
//   series: metadata, // Series minus `episodes`
//   episodes: episodes.map(({ panels, ...episode }) => ({
//     ...episode,
//     panelCount: panels.length,
//   })),
// });
// ```
//
// Seri bulunamazsa route `404` ile `{ "error": "series_not_found" }` döner;
// bu durum `ApiException` (bkz. lib/core/api) tarafında ele alınır, burada
// modellenmez.

import 'package:flutter/foundation.dart';

import 'episode_contract.dart';
import 'schema_version.dart';
import 'series_contract.dart';

/// `GET /api/series/:slug` cevabının tam gövdesi (200 durumunda).
@immutable
class SeriesDetailResponse {
  const SeriesDetailResponse({
    required this.schemaVersion,
    required this.series,
    required this.episodes,
  });

  factory SeriesDetailResponse.fromJson(Map<String, dynamic> json) {
    assertSupportedSchemaVersion(json);
    return SeriesDetailResponse(
      schemaVersion: json['schemaVersion'] as String,
      series: SeriesMetadataContract.fromJson(
        json['series'] as Map<String, dynamic>,
      ),
      episodes: (json['episodes'] as List<dynamic>)
          .map(
            (item) => EpisodeSummaryContract.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }

  final String schemaVersion;
  final SeriesMetadataContract series;
  final List<EpisodeSummaryContract> episodes;
}
