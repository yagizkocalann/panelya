// GEÇİCİ ADAPTER: packages/contracts main'e gelince bu dosya ortak sözleşmeyle
// değiştirilecek (bkz. docs/mobile-handoff.md Ortaklık kuralları #3).
//
// Kaynak: `app/api/catalog/route.ts`.
//
// ```ts
// return Response.json({
//   schemaVersion: "1.0",
//   featuredSlug: featuredSeries?.slug ?? null,
//   series: seriesCatalog.map(({ episodes, ...series }) => ({
//     ...series,
//     episodeCount: episodes.length,
//     latestEpisode: episodes[0],
//   })),
// });
// ```

import 'package:flutter/foundation.dart';

import 'schema_version.dart';
import 'series_contract.dart';

/// `GET /api/catalog` cevabının tam gövdesi.
@immutable
class CatalogResponse {
  const CatalogResponse({
    required this.schemaVersion,
    required this.featuredSlug,
    required this.series,
  });

  factory CatalogResponse.fromJson(Map<String, dynamic> json) {
    assertSupportedSchemaVersion(json);
    return CatalogResponse(
      schemaVersion: json['schemaVersion'] as String,
      featuredSlug: json['featuredSlug'] as String?,
      series: (json['series'] as List<dynamic>)
          .map(
            (item) =>
                SeriesSummaryContract.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  final String schemaVersion;
  final String? featuredSlug;
  final List<SeriesSummaryContract> series;
}
