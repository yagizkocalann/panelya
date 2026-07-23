// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

import 'discovery_episode_update.dart';
import 'discovery_series_summary.dart';
import 'episode_summary.dart';
import 'schema_version.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/DiscoveryResponse`.
class DiscoveryResponse {
  const DiscoveryResponse({
    required this.schemaVersion,
    required this.featuredSeries,
    required this.featuredFirstEpisode,
    required this.genres,
    required this.newSeries,
    required this.latestEpisodes,
  });

  factory DiscoveryResponse.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as String;
    if (schemaVersion != kSchemaVersion) {
      throw FormatException(
        'Desteklenmeyen schemaVersion: $schemaVersion '
        '(beklenen: $kSchemaVersion)',
      );
    }
    final featuredSeriesRaw = json['featuredSeries'];
    final featuredSeries = featuredSeriesRaw == null
        ? null
        : DiscoverySeriesSummary.fromJson(
            featuredSeriesRaw as Map<String, dynamic>,
          );
    final featuredFirstEpisodeRaw = json['featuredFirstEpisode'];
    final featuredFirstEpisode = featuredFirstEpisodeRaw == null
        ? null
        : EpisodeSummary.fromJson(
            featuredFirstEpisodeRaw as Map<String, dynamic>,
          );
    final genres = (json['genres'] as List<dynamic>).cast<String>();
    final newSeries = (json['newSeries'] as List<dynamic>)
        .map(
          (item) => DiscoverySeriesSummary.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
    final latestEpisodes = (json['latestEpisodes'] as List<dynamic>)
        .map(
          (item) => DiscoveryEpisodeUpdate.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
    return DiscoveryResponse(
      schemaVersion: schemaVersion,
      featuredSeries: featuredSeries,
      featuredFirstEpisode: featuredFirstEpisode,
      genres: genres,
      newSeries: newSeries,
      latestEpisodes: latestEpisodes,
    );
  }

  final String schemaVersion;
  final DiscoverySeriesSummary? featuredSeries;
  final EpisodeSummary? featuredFirstEpisode;
  final List<String> genres;
  final List<DiscoverySeriesSummary> newSeries;
  final List<DiscoveryEpisodeUpdate> latestEpisodes;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'featuredSeries': featuredSeries?.toJson(),
      'featuredFirstEpisode': featuredFirstEpisode?.toJson(),
      'genres': genres,
      'newSeries': newSeries.map((e) => e.toJson()).toList(),
      'latestEpisodes': latestEpisodes.map((e) => e.toJson()).toList(),
    };
  }
}
