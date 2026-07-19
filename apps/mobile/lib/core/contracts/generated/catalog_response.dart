// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

import 'schema_version.dart';
import 'series_summary.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/CatalogResponse`.
class CatalogResponse {
  const CatalogResponse({
    required this.schemaVersion,
    required this.featuredSlug,
    required this.series,
  });

  factory CatalogResponse.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as String;
    if (schemaVersion != kSchemaVersion) {
      throw FormatException(
        'Desteklenmeyen schemaVersion: $schemaVersion '
        '(beklenen: $kSchemaVersion)',
      );
    }
    final featuredSlug = json['featuredSlug'] as String?;
    final series = (json['series'] as List<dynamic>)
        .map(
          (item) => SeriesSummary.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
    return CatalogResponse(
      schemaVersion: schemaVersion,
      featuredSlug: featuredSlug,
      series: series,
    );
  }

  final String schemaVersion;
  final String? featuredSlug;
  final List<SeriesSummary> series;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'featuredSlug': featuredSlug,
      'series': series.map((e) => e.toJson()).toList(),
    };
  }
}
