// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

import 'episode_summary.dart';
import 'schema_version.dart';
import 'series_metadata.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/SeriesDetailResponse`.
class SeriesDetailResponse {
  const SeriesDetailResponse({
    required this.schemaVersion,
    required this.series,
    required this.episodes,
  });

  factory SeriesDetailResponse.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as String;
    if (schemaVersion != kSchemaVersion) {
      throw FormatException(
        'Desteklenmeyen schemaVersion: $schemaVersion '
        '(beklenen: $kSchemaVersion)',
      );
    }
    final series = SeriesMetadata.fromJson(
      json['series'] as Map<String, dynamic>,
    );
    final episodes = (json['episodes'] as List<dynamic>)
        .map(
          (item) => EpisodeSummary.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
    return SeriesDetailResponse(
      schemaVersion: schemaVersion,
      series: series,
      episodes: episodes,
    );
  }

  final String schemaVersion;
  final SeriesMetadata series;
  final List<EpisodeSummary> episodes;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'series': series.toJson(),
      'episodes': episodes.map((e) => e.toJson()).toList(),
    };
  }
}
