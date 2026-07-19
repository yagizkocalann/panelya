// GENERATED — elle düzenleme; kaynak: packages/contracts/schema.json, üretici: tool/generate_contracts.dart
// Bu dosyayı elle düzenlemeyin; değişiklik gerekiyorsa
// packages/contracts/schema.json güncellenip codegen yeniden
// çalıştırılmalıdır (dart run tool/generate_contracts.dart).

import 'episode.dart';
import 'episode_manifest_series_ref.dart';
import 'episode_navigation.dart';
import 'schema_version.dart';

/// Kaynak: `packages/contracts/schema.json` -> `$defs/EpisodeManifestResponse`.
class EpisodeManifestResponse {
  const EpisodeManifestResponse({
    required this.schemaVersion,
    required this.series,
    required this.episode,
    required this.navigation,
  });

  factory EpisodeManifestResponse.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as String;
    if (schemaVersion != kSchemaVersion) {
      throw FormatException(
        'Desteklenmeyen schemaVersion: $schemaVersion '
        '(beklenen: $kSchemaVersion)',
      );
    }
    final series = EpisodeManifestSeriesRef.fromJson(
      json['series'] as Map<String, dynamic>,
    );
    final episode = Episode.fromJson(
      json['episode'] as Map<String, dynamic>,
    );
    final navigation = EpisodeNavigation.fromJson(
      json['navigation'] as Map<String, dynamic>,
    );
    return EpisodeManifestResponse(
      schemaVersion: schemaVersion,
      series: series,
      episode: episode,
      navigation: navigation,
    );
  }

  final String schemaVersion;
  final EpisodeManifestSeriesRef series;
  final Episode episode;
  final EpisodeNavigation navigation;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'series': series.toJson(),
      'episode': episode.toJson(),
      'navigation': navigation.toJson(),
    };
  }
}
